//
//  NFBleManager.swift
//  NBForge iOS
//
import Foundation
import CoreBluetooth
import Combine

enum NFState: Equatable {
    case idle, scanning, connecting, connected, activating, working, done(String), failed(String)
}

struct NFDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
}

final class NFBleManager: NSObject, ObservableObject {
    @Published var state: NFState = .idle
    @Published var devices: [NFDevice] = []
    @Published var logs: [String] = []
    @Published var status: String = "就绪"

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txChar: CBCharacteristic?

    private let serviceUUID = CBUUID(string: "FFF0")
    private let charUUID = CBUUID(string: "FFE1")

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        devices.removeAll()
        state = .scanning; status = "扫描中…"
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    func stopScan() { central.stopScan() }

    func connect(_ d: NFDevice) {
        stopScan()
        guard let p = central.retrievePeripherals(withIdentifiers: [d.id]).first else { return }
        peripheral = p; p.delegate = self
        state = .connecting; status = "连接 \(d.name)…"
        central.connect(p, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil; txChar = nil
        state = .idle; status = "已断开"
    }

    func send(_ data: Data) {
        guard let tx = txChar, let p = peripheral else { return }
        log("→ \(data.hexString())")
        p.writeValue(data, for: tx, type: .withResponse)
    }

    private func log(_ s: String) {
        DispatchQueue.main.async {
            self.logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(s)")
            if self.logs.count > 300 { self.logs.removeFirst() }
        }
    }
}

extension NFBleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        if c.state == .poweredOn { log("蓝牙已开启") }
        else { status = "蓝牙不可用"; state = .failed("蓝牙不可用") }
    }
    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "未知"
        let dev = NFDevice(id: p.identifier, name: name, rssi: RSSI.intValue)
        if !devices.contains(where: { $0.id == dev.id }) {
            DispatchQueue.main.async { self.devices.append(dev) }
            log("发现: \(name) \(RSSI)dBm")
        }
    }
    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        log("已连接 \(p.name ?? "")")
        p.delegate = self; p.discoverServices([serviceUUID])
    }
    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        log("断开")
        DispatchQueue.main.async { self.status = "已断开"; self.state = .idle }
    }
}

extension NFBleManager: CBPeripheralDelegate {
    func peripheral(_ p: CBPeripheral, didDiscoverServices e: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics([charUUID], for: s) }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            if ch.uuid == charUUID {
                txChar = ch
                p.setNotifyValue(true, for: ch)
                log("特征值就绪")
                DispatchQueue.main.async { self.state = .connected; self.status = "已连接" }
            }
        }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard let d = ch.value else { return }
        log("← \(d.hexString())")
    }
}

extension Data {
    func hexString() -> String { map { String(format: "%02X", $0) }.joined() }
}
