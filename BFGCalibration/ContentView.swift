//
//  ContentView.swift
//  BFGCalibration iOS
//  主界面
//

import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BFGBleManager()
    @State private var targetVoltage: Int = 48

    var body: some View {
        NavigationStack {
            List {
                Section("连接状态") {
                    HStack {
                        Circle().fill(statusColor).frame(width: 10, height: 10)
                        Text(ble.statusText).font(.subheadline)
                        Spacer()
                        if ble.state == .scanning || ble.state == .connecting { ProgressView() }
                    }
                    HStack {
                        if ble.state == .scanning {
                            Button("停止扫描") { ble.stopScan() }
                        } else {
                            Button("开始扫描") { ble.startScan() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if !ble.discovered.isEmpty {
                    Section("发现的设备 (\(ble.discovered.count))") {
                        ForEach(ble.discovered) { d in
                            Button {
                                ble.connect(d)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(d.name).font(.body)
                                        Text("RSSI: \(d.rssi) dBm").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                if ble.state == .connected || ble.state == .authenticating {
                    Section("校准操作") {
                        Button("发送预通信握手") { ble.sendPrecomm() }
                        Button("读取车型档案") { ble.readProfile() }
                        Button("读取 SOC") { ble.readSOC() }
                        Button("读取仪表盘配置") { ble.readDisConfig() }
                        Picker("目标电压档位", selection: $targetVoltage) {
                            Text("48V").tag(48)
                            Text("60V").tag(60)
                            Text("72V").tag(72)
                        }
                        .pickerStyle(.segmented)
                        Button("写入仪表盘电压", role: .destructive) {
                            ble.writeDisConfig(voltageV: targetVoltage)
                        }
                        .disabled(ble.state == .writing)
                        Text("⚠️ 写入有风险，可能导致仪表盘损坏。请确认已备份原配置。")
                            .font(.caption).foregroundColor(.orange)
                    }
                }

                Section("通信日志") {
                    if ble.logMessages.isEmpty {
                        Text("暂无日志").foregroundColor(.secondary)
                    } else {
                        ForEach(ble.logMessages.indices, id: \.self) { i in
                            Text(ble.logMessages[i])
                                .font(.system(.caption, design: .monospace))
                                .foregroundColor(ble.logMessages[i].contains("✗") ? .red :
                                                 ble.logMessages[i].contains("✓") ? .green : .primary)
                        }
                    }
                }
            }
            .navigationTitle("BFG 电量校准")
        }
    }

    var statusColor: Color {
        switch ble.state {
        case .failed: return .red
        case .finished: return .green
        case .connected, .authenticating, .reading, .writing, .verifying: return .blue
        case .scanning, .connecting, .servicesFound: return .orange
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
}
