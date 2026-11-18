import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var confirmReboot = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "P4-CAN",
                           subtitle: model.overview.firmware.isEmpty ? nil : model.overview.firmware,
                           connected: model.isConnected,
                           trailing: model.overview.updated)

                if !model.isConnected {
                    Banner(title: "未连接设备",
                           detail: model.connectionMessage,
                           tone: .bad)
                }

                if model.overview.setupMode || model.overview.nvsError {
                    Banner(title: "SAFE SETUP MODE",
                           detail: model.overview.nvsError
                                ? "NVS 异常，CAN 与蓝牙未启动。请在设备网页端恢复或选择车型。"
                                : "尚未选择车型，CAN 与蓝牙未启动。请先在设备网页端完成配置。",
                           tone: .warn)
                }

                profileCard
                autopilotCard
                r79Card
                busCard
                deviceCard

                Button(model.isBusy ? "处理中…" : "重启设备") {
                    confirmReboot = true
                }
                .buttonStyle(PrimaryButtonStyle(tone: .bad))
                .disabled(model.isBusy)
                .confirmationDialog("确认重启设备？", isPresented: $confirmReboot, titleVisibility: .visible) {
                    Button("重启", role: .destructive) {
                        Task { await model.reboot() }
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("CAN 会先安全停止再重启，连接会中断数秒。")
                }

                Text("下拉刷新 · 实时数据 1.2 秒刷新")
                    .font(.caption2)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .refreshable {
            await model.refreshFast()
            await model.refreshSlow()
        }
    }

    // MARK: - 车辆配置

    private var profileCard: some View {
        Card("车辆配置", hint: model.overview.topology) {
            InfoRow(label: "车型", value: model.overview.profileName, mono: false)
            DividerLine()
            if !model.overview.turn.isEmpty {
                InfoRow(label: "转向灯变体", value: model.overview.turn, mono: false)
                DividerLine()
            }
            InfoRow(label: "总线映射",
                    sub: "A 路由 / B 路由 / 附加",
                    value: "\(model.overview.canA) · \(model.overview.canB) · \(model.overview.extra)",
                    mono: false)
        }
    }

    // MARK: - 自动驾驶

    private var autopilotCard: some View {
        Card {
            HStack {
                Text("自动驾驶")
                    .font(.caption)
                    .kerning(1.2)
                    .foregroundStyle(Theme.muted)
                Spacer()
                TagView(text: model.overview.apActive ? "AP 激活" : "AP 未激活",
                        tone: model.overview.apActive ? .ok : .idle)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                StatCell(label: "NOA 状态", value: model.overview.noaActive ? "激活" : "未激活", small: true)
                StatCell(label: "NAG 扭矩", value: model.overview.torque)
                StatCell(label: "手扶状态", value: model.overview.handsOn)
                StatCell(label: "档位", value: model.overview.gear, small: true)
                StatCell(label: "DAS 状态字", value: model.overview.dasState)
                StatCell(label: "AP 显示", value: model.overview.displayState)
            }

            if model.overview.canReinitializing {
                HStack {
                    Text("CAN 重初始化中")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    TagView(text: "进行中", tone: .warn)
                }
            }
        }
    }

    // MARK: - R79

    private var r79Card: some View {
        Card {
            HStack {
                Text("R79 扭矩注入")
                    .font(.caption)
                    .kerning(1.2)
                    .foregroundStyle(Theme.muted)
                Spacer()
                TagView(text: model.overview.r79State,
                        tone: model.overview.r79State == "ACTIVE" ? .ok : .idle)
            }
            InfoRow(label: "触发原因", value: model.overview.r79Reason.isEmpty ? "—" : model.overview.r79Reason)
            DividerLine()
            InfoRow(label: "AP 门控", value: model.overview.apGate.isEmpty ? "—" : model.overview.apGate)
            DividerLine()
            InfoRow(label: "发送成功 / 失败", value: "\(model.overview.r79TxOk) / \(model.overview.r79TxFail)")
            DividerLine()
            InfoRow(label: "距上次发送", value: model.overview.r79Age)
        }
    }

    // MARK: - 总线

    private var busCard: some View {
        Card("CAN 总线", hint: "共 \(model.overview.canBusCount) 路") {
            ForEach(model.buses) { bus in
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CAN \(bus.id) · \(bus.name)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.text)
                        Text("流量 \(bus.trafficText) · 静默 \(bus.age)")
                            .font(.caption2)
                            .foregroundStyle(Theme.dim)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("RX \(bus.rx)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Theme.text.opacity(0.85))
                        TagView(text: bus.stateName, tone: bus.tone)
                    }
                }
                .padding(.vertical, 6)
                if bus.id != model.buses.last?.id {
                    DividerLine()
                }
            }
        }
    }

    // MARK: - 设备

    private var deviceCard: some View {
        Card("设备运行") {
            InfoRow(label: "运行时间", value: model.overview.uptime)
            DividerLine()
            InfoRow(label: "空闲内存", value: model.overview.heap)
            DividerLine()
            InfoRow(label: "历史最低内存", value: model.overview.minHeap)
            DividerLine()
            InfoRow(label: "固件版本", value: model.overview.firmware.isEmpty ? "—" : model.overview.firmware)
        }
    }
}

struct OverviewView_Previews: PreviewProvider {
    static var previews: some View {
        OverviewView()
            .environmentObject(DeviceModel())
            .preferredColorScheme(.dark)
    }
}
