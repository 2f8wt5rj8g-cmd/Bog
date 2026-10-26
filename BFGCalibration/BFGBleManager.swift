//
//  BFGBleManager.swift
//  BFGCalibration iOS
//  CoreBluetooth 中央管理者
//

import Foundation
import CoreBluetooth
import Combine

enum BFGBleState: Equatable {
    case idle, scanning, connecting, servicesFound, connected
    case authenticating, reading, writing, verifying
    case finished(String), failed(String)
}

struct BFGDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
}

final class BFGBleManager: NSObject, ObservableObject {

    @Published var state: BFGBleState = .idle
    @Published var discovered: [BFGDevice] = []
    @Published var logMessages: [String] = []
    @Published var statusText: String = "准备就绪"

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txChar: CBCharacteristic?
    private var rxChar: CBCharacteristic?
    private var crypto: BFGEncryption?

    private let knownNameKeywords = ["Ninebot", "Segway", "NB", "QZ", "qzmix", "BFG"]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        discovered.removeAll()
        state = .scanning
        statusText = "正在扫描蓝牙设备…"
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() { central.stopScan() }

    func connect(_ device: BFGDevice) {
        stopScan()
        guard let p = central.retrievePeripherals(withIdentifiers: [device.id]).first else {
            fail("找不到设备 \(device.name)"); return
        }
        peripheral = p
        p.delegate = self
        state = .connecting
        statusText = "正在连接 \(device.name)…"
        central.connect(p, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil; txChar = nil; rxChar = nil
        state = .idle; statusText = "已断开"
    }

    private func sendRaw(_ data: Data) {
        guard let tx = txChar, let p = peripheral else { fail("TX 特征值不可用"); return }
        log("→ \(data.hexString())")
        p.writeValue(data, for: tx, type: .withoutResponse)
    }

    func sendPrecomm() {
        state = .authenticating; statusText = "正在预通信握手…"
        sendRaw(BFGCommand.precomm)
    }

    func readProfile() {
        state = .reading; statusText = "正在读取车型档案…"
        sendRaw(BFGCommand.readProfile)
    }

    func readSOC() {
        statusText = "正在读取 SOC…"
        sendRaw(BFGCommand.readSOC)
    }

    func readDisConfig() {
        statusText = "正在读取仪表盘电压配置…"
        sendRaw(BFGCommand.readDisConfig)
    }

    func writeDisConfig(voltageV: Int) {
        guard let tier = BFGCommand.configByte(forVoltageV: voltageV) else {
            fail("不支持的电压档位: \(voltageV)V"); return
        }
        state = .writing; statusText = "正在写入 \(voltageV)V 配置…"
        sendRaw(BFGCommand.buildWriteDisConfig(voltageTier: tier))
    }

    private func log(_ msg: String) {
        DispatchQueue.main.async {
            self.logMessages.append("[\(Date().formatted(date: .omitted, time: .standard))] \(msg)")
            if self.logMessages.count > 200 { self.logMessages.removeFirst() }
        }
    }

    private func fail(_ msg: String) {
        log("✗ \(msg)")
        DispatchQueue.main.async {
            self.state = .failed(msg); self.statusText = "失败: \(msg)"
        }
    }
}

extension BFGBleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: log("蓝牙已开启")
        case .poweredOff: fail("蓝牙未开启")
        case .unauthorized: fail("未授权蓝牙权限")
        case .unsupported: fail("设备不支持蓝牙")
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "未知设备"
        let matches = knownNameKeywords.contains { name.localizedCaseInsensitiveContains($0) }
            || name.hasPrefix("NB") || name.hasPrefix("QZ")
        guard matches else { return }
        let device = BFGDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if !discovered.contains(where: { $0.id == device.id }) {
            DispatchQueue.main.async { self.discovered.append(device) }
            log("发现: \(name) (\(RSSI) dBm)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("已连接 \(peripheral.name ?? "")")
        state = .servicesFound; statusText = "正在发现服务…"
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: BFGCommand.serviceUUID)])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("断开连接")
        DispatchQueue.main.async { self.statusText = "设备已断开" }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        fail("连接失败: \(error?.localizedDescription ?? "未知")")
    }
}

extension BFGBleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { fail("未发现服务"); return }
        for service in services {
            peripheral.discoverCharacteristics([
                CBUUID(string: BFGCommand.txUUID),
                CBUUID(string: BFGCommand.rxUUID)
            ], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for ch in service.characteristics ?? [] {
            switch ch.uuid.uuidString {
            case BFGCommand.txUUID.uppercased():
                txChar = ch; log("TX 特征值已发现")
            case BFGCommand.rxUUID.uppercased():
                rxChar = ch; peripheral.setNotifyValue(true, for: ch); log("RX notify 已开启")
            default: break
            }
        }
        if txChar != nil && rxChar != nil {
            state = .connected; statusText = "已连接，可以开始操作"
            let name = peripheral.name ?? "BFG"
            crypto = BFGEncryption(deviceName: name)
            log("加密模块初始化完成 (设备名: \(name))")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        log("← \(data.hexString())")
        handleNotify(data)
    }

    private func handleNotify(_ data: Data) {
        guard data.count >= 3 else { return }
        if data[0] == 0x5A && data[1] == 0xA5 {
            switch data[2] {
            case 0x00: log("预通信响应")
            case 0x01 where data.count >= 7:
                let reg = data[5]
                log("读取响应 寄存器=0x\(String(format: "%02X", reg)) 长度=\(data.count)")
            default:
                log("未知功能码: 0x\(String(format: "%02X", data[2]))")
            }
        } else if let crypto = crypto {
            do {
                let plain = try crypto.decryptPreComm(data)
                log("解密后: \(plain.hexString())")
            } catch { log("非明文帧") }
        }
    }
}
