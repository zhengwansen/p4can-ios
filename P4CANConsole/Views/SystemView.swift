import SwiftUI
import UniformTypeIdentifiers

struct SystemView: View {
    @EnvironmentObject private var model: DeviceModel

    private enum PendingAction: String, Identifiable {
        case resetSettings
        case factoryReset
        case reboot

        var id: String { rawValue }

        var title: String {
            switch self {
            case .resetSettings: return "重置固件设置？"
            case .factoryReset: return "恢复出厂设置？"
            case .reboot: return "重启设备？"
            }
        }

        var message: String {
            switch self {
            case .resetSettings: return "恢复功能默认值并重启，车型配置与蓝牙配对会保留。"
            case .factoryReset: return "清除全部 NVS（含车型配置与蓝牙配对），重启后进入 SAFE SETUP MODE。"
            case .reboot: return "CAN 会先安全停止再重启。"
            }
        }

        var button: String {
            switch self {
            case .resetSettings: return "重置"
            case .factoryReset: return "恢复出厂"
            case .reboot: return "重启"
            }
        }
    }

    @State private var baseDraft = ""
    @State private var wifiSSID = ""
    @State private var wifiPassword = ""
    @State private var showImporter = false
    @State private var pickedFile: URL?
    @State private var pickedName = ""
    @State private var pickedSize = ""
    @State private var pending: PendingAction?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "设置",
                           subtitle: model.isBusy ? model.busyAction : model.system.baseURL,
                           connected: model.isConnected,
                           trailing: model.overview.updated)

                if !model.isConnected {
                    Banner(title: "未连接设备", detail: model.connectionMessage, tone: .bad)
                }

                connectionCard
                deviceCard
                wifiCard
                otaCard
                maintenanceCard

                Text("P4-CAN Universal · iOS 控制台\n局域网直连，不经过任何云端服务")
                    .font(.caption2)
                    .foregroundStyle(Theme.dim)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .onAppear { baseDraft = model.system.baseURL }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                pickedFile = url
                pickedName = url.lastPathComponent
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                pickedSize = size > 0 ? ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file) : ""
                model.ota.fileName = pickedName
                model.ota.fileSize = pickedSize.isEmpty ? "-" : pickedSize
                model.ota.stage = "待上传"
                model.ota.progress = 0
            case .failure(let error):
                model.alertMessage = error.localizedDescription
            }
        }
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
            case .resetSettings: await model.resetSettings()
            case .factoryReset: await model.factoryReset()
            case .reboot: await model.reboot()
            }
        }
    }

    // MARK: - 连接

    private var connectionCard: some View {
        Card("连接设置", hint: "默认 \(APIClient.defaultBase)") {
            TextField("http://192.168.4.1", text: $baseDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.text)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.inset))

            HStack(spacing: 10) {
                Button(model.isTesting ? "测试中…" : "保存并测试") {
                    Task { await model.saveBaseURL(baseDraft) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.isTesting)

                Button("恢复默认") {
                    model.resetBaseURL()
                    baseDraft = model.system.baseURL
                }
                .buttonStyle(GhostButtonStyle())
            }

            Button("接口自检") {
                Task { await model.runSelfChecks() }
            }
            .buttonStyle(GhostButtonStyle())

            if !model.selfChecks.isEmpty {
                DividerLine()
                ForEach(model.selfChecks) { check in
                    HStack(alignment: .top, spacing: 8) {
                        TagView(text: check.ok ? "OK" : "FAIL", tone: check.ok ? .ok : .bad)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.name)
                                .font(.caption)
                                .foregroundStyle(Theme.text.opacity(0.9))
                            Text(check.detail)
                                .font(.caption2)
                                .foregroundStyle(Theme.dim)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 3)
                }
            }

            Text("手机需先连上设备热点 P4-CAN-XXXX；iOS 提示「无互联网连接」时选择保持连接。")
                .font(.caption2)
                .foregroundStyle(Theme.dim)
        }
    }

    // MARK: - 设备

    private var deviceCard: some View {
        Card("设备信息") {
            InfoRow(label: "固件版本", value: model.system.firmware)
            DividerLine()
            InfoRow(label: "当前车型", value: model.system.profile, mono: false)
            DividerLine()
            InfoRow(label: "运行时间", value: model.system.uptime)
            DividerLine()
            InfoRow(label: "空闲 / 最低内存", value: "\(model.system.heap) / \(model.system.minHeap)")
            DividerLine()
            Button("复制诊断信息") { model.copyDiagnostics() }
                .buttonStyle(GhostButtonStyle())
        }
    }

    // MARK: - Wi-Fi

    private var wifiCard: some View {
        Card("Wi-Fi 热点", hint: "SoftAP · 192.168.4.1") {
            InfoRow(label: "当前 SSID", value: model.system.wifiSSID.isEmpty ? "—" : model.system.wifiSSID)
            DividerLine()
            InfoRow(label: "设备 IP", value: model.system.wifiIP.isEmpty ? "—" : model.system.wifiIP)
            DividerLine()

            if model.system.wifiPasswordIsDefault {
                Banner(title: "仍在使用默认密码 12345678",
                       detail: "任何连上热点的人都能调用全部接口，建议立即修改。",
                       tone: .warn)
                    .padding(.vertical, 4)
            }

            HStack {
                Text("SSID")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .frame(width: 56, alignment: .leading)
                TextField("P4-CAN-XXXX", text: $wifiSSID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.inset))
            }

            HStack {
                Text("新密码")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .frame(width: 56, alignment: .leading)
                SecureField("留空沿用原密码", text: $wifiPassword)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.inset))
            }

            Button("应用热点设置") {
                Task { await model.applyWiFi(ssid: wifiSSID, password: wifiPassword) }
            }
            .buttonStyle(GhostButtonStyle())

            Text("修改后热点会重建，手机需重新连接；密码 8-63 位，留空沿用原密码。")
                .font(.caption2)
                .foregroundStyle(Theme.dim)

            if model.system.hasWifiStatus && !model.system.wifiRaw.isEmpty {
                DisclosureGroup {
                    Text(model.system.wifiRaw)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .textSelection(.enabled)
                        .padding(.top, 6)
                } label: {
                    Text("/api/wifi/status")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                .tint(Theme.accent)
            }
        }
    }

    // MARK: - OTA

    private var otaCard: some View {
        Card {
            HStack {
                Text("固件升级 · OTA")
                    .font(.caption)
                    .kerning(1.2)
                    .foregroundStyle(Theme.muted)
                Spacer()
                TagView(text: model.ota.running ? "进行中" : "待命",
                        tone: model.ota.running ? .warn : .idle)
            }

            InfoRow(label: "已选文件", value: pickedName.isEmpty ? "未选择" : pickedName, mono: false)
            if !pickedSize.isEmpty {
                DividerLine()
                InfoRow(label: "文件大小", value: pickedSize)
            }

            ProgressView(value: min(max(model.ota.progress, 0), 100), total: 100)
                .tint(Theme.accent)

            InfoRow(label: "状态", value: model.ota.stage, mono: false)
            InfoRow(label: "设备回报", value: "\(model.ota.received) / \(model.ota.total)")

            HStack(spacing: 10) {
                Button("选择固件") { showImporter = true }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.ota.running)

                Button(model.ota.running ? "上传中…" : "开始升级") {
                    guard let url = pickedFile else { return }
                    Task { await model.uploadFirmware(from: url) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.ota.running || pickedFile == nil)
            }

            Text("请选择 app 镜像（约 1.39 MB），不要选 32 MB 合并镜像。可从「文件」App 或 iCloud 云盘导入。")
                .font(.caption2)
                .foregroundStyle(Theme.dim)
        }
    }

    // MARK: - 维护

    private var maintenanceCard: some View {
        Card("维护", hint: "危险操作") {
            Button("重置固件设置（保留车型 / 蓝牙）") { pending = .resetSettings }
                .buttonStyle(GhostButtonStyle())
                .disabled(model.isBusy)

            Button("恢复出厂设置（清除全部 NVS）") { pending = .factoryReset }
                .buttonStyle(PrimaryButtonStyle(tone: .bad))
                .disabled(model.isBusy)

            Button("重启设备") { pending = .reboot }
                .buttonStyle(PrimaryButtonStyle(tone: .bad))
                .disabled(model.isBusy)
        }
    }
}

struct SystemView_Previews: PreviewProvider {
    static var previews: some View {
        SystemView()
            .environmentObject(DeviceModel())
            .preferredColorScheme(.dark)
    }
}
