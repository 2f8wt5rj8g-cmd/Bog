//
//  BFGProtocol.swift
//  BFGCalibration iOS
//  蓝牙帧组装与解析
//

import Foundation

enum BFGCommand {
    static let serviceUUID  = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
    static let txUUID      = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    static let rxUUID      = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    static let cccdUUID    = "00002902-0000-1000-8000-00805f9b34fb"

    static let precomm     = Data(hex: "5AA5003E045B00")!
    static let readProfile = Data(hex: "5AA5013E10010001")!
    static let readSOC     = Data(hex: "5AA5013E10010201")!
    static let readCapacity = Data(hex: "5AA5013E10011C02")!
    static let readDisBattery = Data(hex: "5AA5013E0101B502")!
    static let readDisVRLAVoltage = Data(hex: "5AA5013E0101B102")!
    static let readDisBFGVersion = Data(hex: "5AA5013E01013D02")!
    static let readDisDashboardVersion = Data(hex: "5AA5013E01011A02")!
    static let readColorDisplayVersion = Data(hex: "5AA5013E0101D102")!
    static let readCentreControllerVersion = Data(hex: "5AA5013E09010202")!
    static let readDisEnergyWH = Data(hex: "5AA5013E01011E02")!
    static let readDisRemainingCapacity = Data(hex: "5AA5013E01014402")!
    static let readDisConfig = Data(hex: "5AA5013E01019202")!

    static func buildAuth(sn: Data) -> Data {
        precondition(sn.count == 14, "SN must be 14 bytes")
        var frame = Data(hex: "5AA50E3E045D00")!
        frame.append(sn)
        return frame
    }

    static func buildReadWord(_ reg: UInt8, len: UInt8 = 1) -> Data {
        var frame = Data(hex: "5AA5013E1001")!
        frame.append(reg)
        frame.append(len)
        return frame
    }

    static func buildWriteDisConfig(voltageTier: UInt8) -> Data {
        var frame = Data(hex: "5AA5043E010192")!
        frame.append(voltageTier)
        return frame
    }

    static let coreByIndex: [Int] = [
        20000, 10500, 18000, 36000,
        10500, 25992, 14000, 38000,
        13000, 22000, 39000, 45000,
        46000, 55000, 52000, 18000
    ]

    static func voltageTier(forConfigByte cfg: UInt8) -> Int? {
        switch cfg & 0x0F {
        case 1: return 48
        case 2: return 60
        case 3: return 72
        default: return nil
        }
    }

    static func configByte(forVoltageV v: Int) -> UInt8? {
        switch v {
        case 48: return 1
        case 60: return 2
        case 72: return 3
        default: return nil
        }
    }
}
