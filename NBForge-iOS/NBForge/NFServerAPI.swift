//
//  NFServerAPI.swift
//  NBForge iOS
//
import Foundation

enum NFServer {
    static let base = "https://nbforge.pen-net.cn"

    static func activate(sn: String, pn: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(base)/activate.php") else { throw NFError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "sn=\(sn)&pn=\(pn)".data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    static func checkVersion() async throws -> [String: Any] {
        guard let url = URL(string: "\(base)/checkver.php") else { throw NFError.badURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

enum NFError: Error { case badURL }
