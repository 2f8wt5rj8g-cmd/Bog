//
//  BFGEncryption.swift
//  BFGCalibration iOS
//  AES-128-CTR 加解密 + SHA1 密钥派生（从安卓版 Encryption2 移植）
//

import Foundation
import CommonCrypto

enum BFGCryptoError: Error {
    case shortFrame
    case invalidKey
    case aesFailure
}

final class BFGEncryption {

    /// 安卓版 DATA_BASIC 静态种子
    static let dataBasic = Data(hex: "97CFB802844143DE56002B3B34780A5D")!

    private var initialKey: Data
    private var sessionKey: Data?
    private var authParam: Data?

    init(deviceName: String) {
        let nameBytes = deviceName.data(using: .utf8) ?? Data()
        self.initialKey = BFGEncryption.deriveKey(BFGEncryption.pad16(nameBytes), BFGEncryption.dataBasic)
    }

    static func deriveKey(_ a: Data, _ b: Data) -> Data {
        var combined = pad16(a)
        combined.append(pad16(b))
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        combined.withUnsafeBytes { buf in
            CC_SHA1(buf.baseAddress, CC_LONG(combined.count), &digest)
        }
        return Data(digest.prefix(16))
    }

    static func pad16(_ data: Data) -> Data {
        var out = Data(count: 16)
        let n = min(data.count, 16)
        out.replaceSubrange(0..<n, with: data.prefix(n))
        return out
    }

    static func aesECB(key: Data, _ data: Data) throws -> Data {
        guard key.count == 16 else { throw BFGCryptoError.invalidKey }
        let padded = data.count % 16 == 0 ? data : data + Data(count: 16 - data.count % 16)
        var out = Data(count: padded.count)
        var status: CCCryptorStatus = 0
        out.withUnsafeMutableBytes { outBuf in
            padded.withUnsafeBytes { inBuf in
                key.withUnsafeBytes { keyBuf in
                    status = CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyBuf.baseAddress, 16,
                        nil,
                        inBuf.baseAddress, padded.count,
                        outBuf.baseAddress, out.count,
                        nil
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw BFGCryptoError.aesFailure }
        return out
    }

    static func cryptCTR(key: Data, seed: Data, counter: UInt8, payload: Data) throws -> Data {
        var block = Data(count: 16)
        let seedLen = min(seed.count, 10)
        block.replaceSubrange(0..<seedLen, with: seed.prefix(seedLen))
        block[10] = counter
        block[11] = 0
        block[12] = 0
        let keystream = try aesECB(key: key, block)
        var result = Data(count: payload.count)
        for i in 0..<payload.count {
            result[i] = payload[i] ^ keystream[i % 16]
        }
        return result
    }

    func establishSession(authParam: Data, password: Data) {
        self.authParam = authParam
        self.sessionKey = BFGEncryption.deriveKey(authParam, BFGEncryption.pad16(password))
    }

    func establishNameSession(_ challenge: Data) {}

    func encryptPreComm(_ plain: Data) throws -> Data {
        guard plain.count >= 9 else { throw BFGCryptoError.shortFrame }
        var frame = Data(plain.prefix(2))
        let body = plain.subdata(in: 2..<plain.count)
        let encrypted = try BFGEncryption.cryptCTR(key: initialKey, seed: initialKey.prefix(10), counter: body[0], payload: body)
        frame.append(encrypted)
        return frame
    }

    func decryptPreComm(_ frame: Data) throws -> Data {
        guard frame.count >= 9 else { throw BFGCryptoError.shortFrame }
        var plain = Data(frame.prefix(2))
        let body = frame.subdata(in: 2..<frame.count)
        let decrypted = try BFGEncryption.cryptCTR(key: initialKey, seed: initialKey.prefix(10), counter: body[0], payload: body)
        plain.append(decrypted)
        return plain
    }

    func encryptSn(_ payload: Data, counter: UInt8) throws -> Data {
        guard let key = sessionKey else { throw BFGCryptoError.shortFrame }
        return try BFGEncryption.cryptCTR(key: key, seed: initialKey.prefix(10), counter: counter, payload: payload)
    }

    func decryptSn(_ frame: Data, counter: UInt8) throws -> Data {
        guard let key = sessionKey else { throw BFGCryptoError.shortFrame }
        return try BFGEncryption.cryptCTR(key: key, seed: initialKey.prefix(10), counter: counter, payload: frame)
    }
}

extension Data {
    init?(hex: String) {
        let clean = hex.replacingOccurrences(of: " ", with: "")
        guard clean.count % 2 == 0 else { return nil }
        self.init(capacity: clean.count / 2)
        var start = clean.startIndex
        for _ in 0..<clean.count / 2 {
            let end = clean.index(start, offsetBy: 2)
            guard let byte = UInt8(clean[start..<end], radix: 16) else { return nil }
            self.append(byte)
            start = end
        }
    }
    func hexString() -> String {
        map { String(format: "%02X", $0) }.joined()
    }
}
