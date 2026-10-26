//
//  ContentView.swift
//  NBForge iOS
//
import SwiftUI

struct ContentView: View {
    @StateObject var ble = NFBleManager()
    @State private var sn = ""
    @State private var pn = ""
    @State private var serverResult = ""

    var body: some View {
        NavigationStack {
            List {
                Section("连接状态") {
                    HStack {
                        Circle().fill(ble.stateColor).frame(width: 10, height: 10)
                        Text(ble.status).font(.subheadline)
                        Spacer()
                        if ble.state == .scanning || ble.state == .connecting { ProgressView() }
                    }
                    Button(ble.state == .scanning ? "停止" : "扫描设备") {
                        ble.state == .scanning ? ble.stopScan() : ble.startScan()
                    }
                }
                if !ble.devices.isEmpty {
                    Section("设备") {
                        ForEach(ble.devices) { d in
                            Button(d.name) { ble.connect(d) }
                        }
                    }
                }
                Section("车辆激活") {
                    TextField("车架号 SN", text: $sn).textInputAutocapitalization(.characters)
                    TextField("零件号 PN", text: $pn).textInputAutocapitalization(.characters)
                    Button("激活") {
                        Task {
                            do {
                                let r = try await NFServer.activate(sn: sn, pn: pn)
                                serverResult = "\(r)"
                            } catch { serverResult = "错误: \(error)" }
                        }
                    }
                    if !serverResult.isEmpty {
                        Text(serverResult).font(.caption).foregroundColor(.secondary)
                    }
                }
                Section("通信日志") {
                    if ble.logs.isEmpty {
                        Text("暂无").foregroundColor(.secondary)
                    } else {
                        ForEach(ble.logs.indices, id: \.self) { i in
                            Text(ble.logs[i]).font(.system(.caption, design: .monospace))
                        }
                    }
                }
            }
            .navigationTitle("NBForge")
        }
    }
}

extension NFBleManager {
    var stateColor: Color {
        switch state {
        case .failed: return .red
        case .connected, .working: return .green
        case .scanning, .connecting: return .orange
        case .done: return .blue
        default: return .gray
        }
    }
}

#Preview { ContentView() }
