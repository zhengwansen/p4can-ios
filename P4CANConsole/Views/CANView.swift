import SwiftUI

struct CANView: View {
    @EnvironmentObject private var model: DeviceModel

    private enum PendingAction: String, Identifiable {
        case resetStats
        case reinitCAN

        var id: String { rawValue }

        var title: String {
            switch self {
            case .resetStats: return "清零全部运行统计？"
            case .reinitCAN: return "强制重初始化 CAN？"
            }
        }

        var message: String {
            switch self {
            case .resetStats: return "会清零 RX/TX、总线错误与恢复计数，不影响 CAN 收发。"
            case .reinitCAN: return "三路 TWAI 会短暂停止并重新安装，期间不会发送任何报文。"
            }
        }

        var button: String {
            switch self {
            case .resetStats: return "清零"
            case .reinitCAN: return "重初始化"
            }
        }
    }

    @State private var pending: PendingAction?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "CAN 总线",
                           subtitle: "3 × TWAI · 500 kbit/s",
                           connected: model.isConnected,
                           trailing: model.overview.updated)

                if !model.isConnected {
                    Banner(title: "未连接设备", detail: model.connectionMessage, tone: .bad)
                }

                ForEach(model.buses) { bus in
                    busCard(bus)
                }

                trafficCard
                actions
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .refreshable { await model.refreshSlow() }
        .confirmationDialog(pending?.title ?? "",
                            isPresented: dialogBinding,
                            titleVisibility: .visible) {
            Button(pending?.button ?? "确认", role: .destructive) { performPending() }
            Button("取消", role: .cancel) { pending = nil }
        } message: {
            Text(pending?.message ?? "")
        }
    }

    private var dialogBinding: Binding<Bool> {
        Binding(
            get: { pending != nil },
            set: { presented in if !presented { pending = nil } }
        )
    }

    private func performPending() {
        let action = pending
        pending = nil
        guard let action else { return }
        Task {
            switch action {
            case .resetStats: await model.resetStats()
            case .reinitCAN: await model.reinitCAN()
            }
        }
    }

    private func busCard(_ bus: BusState) -> some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CAN \(bus.id) · \(bus.name)")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text("\(bus.mode.isEmpty ? "—" : bus.mode) · TX GPIO\(bus.txPin) / RX GPIO\(bus.rxPin)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Theme.dim)
                }
                Spacer(minLength: 8)
                TagView(text: bus.stateName, tone: bus.tone)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                StatCell(label: "接收帧数", value: bus.rx)
                StatCell(label: "最近流量", value: bus.age, small: true)
                StatCell(label: "TX 成功 / 拒绝", value: "\(bus.txOk) / \(bus.txFail)", small: true)
                StatCell(label: "总线关闭次数", value: bus.busOff)
                StatCell(label: "TEC / REC", value: "\(bus.tec) / \(bus.rec)", small: true)
                StatCell(label: "总线错误 / 仲裁丢失", value: "\(bus.busErrors) / \(bus.arbLost)", small: true)
            }

            DividerLine()

            InfoRow(label: "RX 轮询", value: bus.polls)
            InfoRow(label: "丢帧 / 溢出", value: "\(bus.missed) / \(bus.overrun)")
            InfoRow(label: "驱动发送失败", value: bus.driverTxFailed)
            InfoRow(label: "恢复成功 / 失败", value: "\(bus.recoveries) / \(bus.recoveryFailures)")
            InfoRow(label: "初始化 / 最近 RX",
                    value: "\(bus.initResult.isEmpty ? "—" : bus.initResult) / \(bus.rxResult.isEmpty ? "—" : bus.rxResult)")
            InfoRow(label: "状态快照年龄", value: bus.statusAge)
        }
    }

    private var trafficCard: some View {
        Card("流量与溢出") {
            InfoRow(label: "A 路由原生接收",
                    value: "\(model.traffic.nativeOnline ? "在线" : "静默") · \(model.traffic.nativeAge)",
                    mono: false)
            DividerLine()
            InfoRow(label: "B 路由 TWAI 接收",
                    value: "\(model.traffic.twaiOnline ? "在线" : "静默") · \(model.traffic.twaiAge)",
                    mono: false)
            DividerLine()
            InfoRow(label: "原生 RX 溢出", value: "\(model.traffic.overflow) 次 · \(model.traffic.overflowAge) 前")
            DividerLine()
            InfoRow(label: "运行时间 / 空闲内存", value: "\(model.system.uptime) · \(model.system.heap)")
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("清零统计") { pending = .resetStats }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.isBusy)

                Button("重初始化 CAN") { pending = .reinitCAN }
                    .buttonStyle(PrimaryButtonStyle(tone: .bad))
                    .disabled(model.isBusy)
            }

            Text("总线关闭后由恢复监督任务自动重启；重初始化期间不会发送任何报文")
                .font(.caption2)
                .foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center)
        }
    }
}

struct CANView_Previews: PreviewProvider {
    static var previews: some View {
        CANView()
            .environmentObject(DeviceModel())
            .preferredColorScheme(.dark)
    }
}
