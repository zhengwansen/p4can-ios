import Combine
import Foundation
import UIKit

@MainActor
final class DeviceModel: ObservableObject {
    @Published var overview = OverviewState()
    @Published var buses: [BusState] = [BusState(id: 1), BusState(id: 2), BusState(id: 3)]
    @Published var traffic = TrafficState()
    @Published var control = ControlState()
    @Published var system = SystemState()
    @Published var ota = OTAState()

    @Published var isConnected = false
    @Published var connectionMessage = ""
    @Published var busyAction: String?
    @Published var alertMessage: String?
    @Published var toast: String?
    @Published var selfChecks: [SelfCheckItem] = []
    @Published var isTesting = false

    private let api = APIClient.shared
    private var fastTask: Task<Void, Never>?
    private var slowTask: Task<Void, Never>?
    private var otaTask: Task<Void, Never>?

    var isBusy: Bool { busyAction != nil }

    // MARK: - 生命周期

    func start() async {
        system.baseURL = api.baseURLString
        if fastTask == nil {
            fastTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refreshFast()
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                }
            }
        }
        if slowTask == nil {
            slowTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refreshSlow()
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                }
            }
        }
    }

    func stop() {
        fastTask?.cancel()
        slowTask?.cancel()
        otaTask?.cancel()
        fastTask = nil
        slowTask = nil
        otaTask = nil
    }

    // MARK: - 轮询

    func refreshFast() async {
        do {
            let snapshot = try await api.get("/api/snapshot", query: ["groups": "home-fast"])
            applyFast(snapshot)
            markConnected()
        } catch {
            markDisconnected(error)
        }
    }

    func refreshSlow() async {
        let profile = (try? await api.get("/api/profile/status")) ?? .empty
        let settings = (try? await api.get("/api/snapshot", query: ["groups": "settings-lite"])) ?? .empty
        let stats = (try? await api.get("/api/system/stats")) ?? .empty
        let wifi = (try? await api.get("/api/wifi/status")) ?? .empty

        if !profile.isEmpty || !stats.isEmpty {
            markConnected()
        }
        applyProfile(profile, settings: settings)
        applySystem(stats, wifi: wifi, settings: settings)
        await loadControl()
    }

    private func markConnected() {
        if !isConnected {
            isConnected = true
        }
        connectionMessage = ""
        overview.updated = Fmt.clock()
    }

    private func markDisconnected(_ error: Error) {
        isConnected = false
        connectionMessage = error.localizedDescription
    }

    // MARK: - 映射

    private func applyFast(_ snapshot: Payload) {
        let nag = snapshot.obj("nag")
        let blink = snapshot.obj("blink")
        let r79 = snapshot.obj("r79")

        overview.apActive = nag.bool("apActive") ?? false
        overview.noaActive = blink.bool("noaActive") ?? false
        overview.torque = Fmt.torque(nag.double("torque"))
        overview.handsOn = Fmt.count(nag.int("handsOnState"))
        overview.canReinitializing = blink.bool("canReinitializing") ?? false
        overview.dasState = (blink.bool("dasStateValid") ?? false) ? Fmt.count(blink.int("dasState")) : "—"
        overview.displayState = (blink.bool("displayStateValid") ?? false) ? Fmt.count(blink.int("displayState")) : "—"

        overview.gear = r79.str("gearName") ?? "—"
        overview.r79State = r79.str("txState") ?? "—"
        overview.r79Reason = r79.str("txReason") ?? ""
        overview.apGate = r79.str("apGateReason") ?? ""
        overview.r79TxOk = Fmt.count(r79.int("txOk"))
        overview.r79TxFail = Fmt.count(r79.int("txFail"))
        overview.r79Age = Fmt.age(r79.int("lastTxAgeMs"))

        updateBuses(snapshot.obj("cantraffic"), detailed: false, trafficFrom: snapshot.obj("cantraffic"))
    }

    private func applyProfile(_ profile: Payload, settings: Payload) {
        if !profile.isEmpty {
            overview.profileName = profile.str("profileName") ?? "—"
            overview.topology = profile.str("topologyName") ?? ""
            overview.canA = profile.str("canA") ?? "—"
            overview.canB = profile.str("canB") ?? "—"
            overview.extra = profile.str("canExtra") ?? "—"
            overview.turn = profile.str("turnName") ?? ""
            overview.setupMode = profile.bool("setupMode") ?? false
            overview.nvsError = profile.bool("nvsError") ?? false
            overview.canBusCount = profile.int("canBusCount") ?? 3
        }
        let systemBlock = settings.obj("system")
        let blink = settings.obj("blink")
        let summon = settings.obj("summon")
        if !settings.isEmpty {
            overview.firmware = systemBlock.str("fwVersion") ?? overview.firmware
            control.blinkEnabled = blink.bool("enabled") ?? control.blinkEnabled
            control.blinkDelay = blink.double("delayMs") ?? control.blinkDelay
            control.tlssc = summon.bool("tlssc") ?? control.tlssc
        }
    }

    private func applySystem(_ stats: Payload, wifi: Payload, settings: Payload) {
        if !stats.isEmpty {
            overview.uptime = Fmt.duration(stats.int("uptimeS"))
            overview.heap = Fmt.bytes(stats.int("freeHeap"))
            overview.minHeap = Fmt.bytes(stats.int("minFreeHeap"))
            system.uptime = overview.uptime
            system.heap = overview.heap
            system.minHeap = overview.minHeap
            updateBuses(stats, detailed: true, trafficFrom: nil)
        }
        system.firmware = overview.firmware
        system.profile = overview.profileName
        system.baseURL = api.baseURLString
        if !wifi.isEmpty {
            system.hasWifiStatus = true
            system.wifiSSID = wifi.str("ssid") ?? system.wifiSSID
            system.wifiIP = wifi.str("ip") ?? system.wifiIP
            system.wifiPasswordIsDefault = wifi.bool("passwordIsDefault") ?? false
            system.wifiRaw = wifi.compactJSON()
        }
    }

    private func updateBuses(_ source: Payload, detailed: Bool, trafficFrom: Payload?) {
        var result: [BusState] = []
        for index in 1...3 {
            var bus = buses.first(where: { $0.id == index }) ?? BusState(id: index)
            let stateValue = source.int("can\(index)State")
            bus.name = source.str("can\(index)Name") ?? "CAN \(index)"
            bus.stateName = Fmt.twaiState(stateValue)
            bus.tone = Fmt.twaiTone(stateValue)
            bus.ready = source.bool("can\(index)Ready") ?? false
            bus.online = source.bool("can\(index)TrafficOnline") ?? false
            bus.trafficText = bus.online ? "在线" : ((source.bool("can\(index)TrafficSeen") ?? false) ? "静默" : "无流量")
            bus.age = Fmt.age(source.int("can\(index)TrafficAgeMs"))
            bus.rx = Fmt.count(source.int("can\(index)RxCount"))
            bus.txOk = Fmt.count(source.int("can\(index)TxAccepted"))
            bus.txFail = Fmt.count(source.int("can\(index)TxRejected"))
            bus.busOff = Fmt.count(source.int("can\(index)BusOffCount"))
            bus.missed = Fmt.count(source.int("can\(index)RxMissed"))
            bus.overrun = Fmt.count(source.int("can\(index)RxOverrun"))
            bus.txPin = Fmt.count(source.int("can\(index)TxPin"))
            bus.rxPin = Fmt.count(source.int("can\(index)RxPin"))
            bus.mode = source.str("can\(index)Mode") ?? bus.mode

            if detailed {
                bus.tec = Fmt.count(source.int("can\(index)Tec"))
                bus.rec = Fmt.count(source.int("can\(index)Rec"))
                bus.polls = Fmt.count(source.int("can\(index)RxPolls"))
                bus.busErrors = Fmt.count(source.int("can\(index)BusErrors"))
                bus.arbLost = Fmt.count(source.int("can\(index)ArbLost"))
                bus.driverTxFailed = Fmt.count(source.int("can\(index)DriverTxFailed"))
                bus.recoveries = Fmt.count(source.int("can\(index)Recoveries"))
                bus.recoveryFailures = Fmt.count(source.int("can\(index)RecoveryFailures"))
                bus.initResult = source.str("can\(index)InitResult") ?? ""
                bus.rxResult = source.str("can\(index)RxResult") ?? ""
                bus.statusAge = Fmt.age(source.int("can\(index)StatusAgeMs"))
            }

            if let traffic = trafficFrom {
                self.traffic.nativeAge = Fmt.age(traffic.int("nativeATrafficAgeMs"))
                self.traffic.nativeOnline = traffic.bool("nativeATrafficOnline") ?? false
                self.traffic.twaiAge = Fmt.age(traffic.int("twaiTrafficAgeMs"))
                self.traffic.twaiOnline = traffic.bool("twaiTrafficOnline") ?? false
                self.traffic.overflow = Fmt.count(traffic.int("nativeARxOverflowCount"))
                self.traffic.overflowAge = Fmt.age(traffic.int("nativeARxOverflowLastAgeMs"))
            }
            result.append(bus)
        }
        buses = result
    }

    private func loadControl() async {
        let nag = (try? await api.get("/api/nag/config")) ?? .empty
        let features = (try? await api.get("/api/features/status")) ?? .empty
        let dms = (try? await api.get("/api/driver-monitoring/config")) ?? .empty
        let isa = (try? await api.get("/api/isa-suppression/config")) ?? .empty
        let ulc = (try? await api.get("/api/ulc/stats")) ?? .empty
        let country = (try? await api.get("/api/country/stats")) ?? .empty

        if !nag.isEmpty {
            control.nagEnabled = nag.bool("enabled") ?? control.nagEnabled
            let method = nag.int("method") ?? 0
            control.nagMethodIndex = Options.nagMethods.firstIndex(of: method) ?? 0
            control.nagMethodName = nag.str("methodName") ?? ""
        }
        if !features.isEmpty {
            control.lab = features.bool("lab") ?? control.lab
        }
        if !dms.isEmpty {
            control.dmsEnabled = dms.bool("enabled") ?? false
            control.dmsSupported = dms.bool("supported") ?? true
            control.dmsActive = dms.bool("active") ?? false
        }
        if !isa.isEmpty {
            control.isaEnabled = isa.bool("enabled") ?? false
            control.isaSupported = isa.bool("supported") ?? true
            control.isaActive = isa.bool("active") ?? false
        }
        if !ulc.isEmpty {
            control.ulcRaw = ulc.compactJSON()
            if let alc = ulc.int("alcMode") {
                control.ulcAlcOff = alc != 0
            }
        }
        if !country.isEmpty {
            control.countryIndex = country.int("countryMode") ?? control.countryIndex
            control.mapIndex = country.int("mapMode") ?? control.mapIndex
            control.countrySupported = country.bool("countrySupported") ?? true
            control.countryRaw = country.compactJSON()
        }
    }

    // MARK: - 动作执行

    private enum RefreshTarget {
        case fast
        case control
        case slow
        case none
    }

    private func run(_ label: String,
                     target: RefreshTarget = .control,
                     _ block: @escaping () async throws -> Payload) async {
        busyAction = label
        defer { busyAction = nil }
        do {
            _ = try await block()
            switch target {
            case .fast: await refreshFast()
            case .control: await loadControl()
            case .slow: await refreshSlow()
            case .none: break
            }
            showToast("\(label) 成功")
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func showToast(_ text: String) {
        toast = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if self?.toast == text { self?.toast = nil }
        }
    }

    // MARK: NAG

    func setNAGEnabled(_ enabled: Bool) async {
        await run("NAG 开关") { try await self.api.post("/api/nag/update", form: ["enabled": enabled ? "1" : "0"]) }
        control.nagEnabled = enabled
    }

    func setNAGMethod(_ index: Int) async {
        let method = Options.nagMethods[index]
        await run("注入方法") { try await self.api.post("/api/nag/update", form: ["method": "\(method)"]) }
        control.nagMethodIndex = index
    }

    func setNAGMode(_ index: Int) async {
        let mode = Options.nagModes[index]
        await run("模式模板") { try await self.api.post("/api/nag/mode", form: ["m": "\(mode)"]) }
        control.nagModeIndex = index
    }

    // MARK: EAP / TLSSC / LAB

    func setBlinkEnabled(_ enabled: Bool) async {
        let path = enabled ? "/api/blinkA/enable" : "/api/blinkA/disable"
        await run(enabled ? "自动转向灯开启" : "自动转向灯关闭") { try await self.api.post(path) }
        control.blinkEnabled = enabled
    }

    func setBlinkDelay(_ milliseconds: Int) async {
        await run("转向灯延时") { try await self.api.post("/api/blinkA/delay", form: ["ms": "\(milliseconds)"]) }
        control.blinkDelay = Double(milliseconds)
    }

    func setTLSSCC(_ enabled: Bool) async {
        let path = enabled ? "/api/summon/tlssc-enable" : "/api/summon/tlssc-disable"
        await run(enabled ? "TLSSC 开启" : "TLSSC 关闭") { try await self.api.post(path) }
        control.tlssc = enabled
    }

    func setLAB(_ enabled: Bool) async {
        await run(enabled ? "实验室模式开启" : "实验室模式关闭") {
            try await self.api.post("/api/features/lab", form: ["enabled": enabled ? "1" : "0"])
        }
        control.lab = enabled
    }

    // MARK: 驾驶辅助

    func setDMS(_ enabled: Bool) async {
        await run("驾驶员监控") {
            try await self.api.post("/api/driver-monitoring/config", form: ["enabled": enabled ? "1" : "0"])
        }
        control.dmsEnabled = enabled
    }

    func setISA(_ enabled: Bool) async {
        await run("ISA 提示音抑制") {
            try await self.api.post("/api/isa-suppression/config", form: ["enabled": enabled ? "1" : "0"])
        }
        control.isaEnabled = enabled
    }

    // MARK: ULC

    func setULCAlcOff(_ enabled: Bool) async {
        await run("ULC 自动变道") {
            try await self.api.post("/api/ulc/update", form: ["alcOff": enabled ? "1" : "0"])
        }
        control.ulcAlcOff = enabled
    }

    func setULCOff(_ index: Int) async {
        let value = Options.ulcOffValues[index]
        await run("ULC Off 模式") { try await self.api.post("/api/ulc/update", form: ["ulcOff": value]) }
        control.ulcOffIndex = index
    }

    func setULCBlind(_ index: Int) async {
        let value = Options.blindValues[index]
        await run("盲区模式") { try await self.api.post("/api/ulc/update", form: ["blind": value]) }
        control.ulcBlindIndex = index
    }

    func setULCTiming(_ index: Int) async {
        let value = Options.timingValues[index]
        await run("确认时序") { try await self.api.post("/api/ulc/update", form: ["timing": "\(value)"]) }
        control.ulcTimingIndex = index
    }

    func setULCConfirm(_ enabled: Bool) async {
        await run("免确认变道") {
            try await self.api.post("/api/ulc/update", form: ["confirm": enabled ? "1" : "0"])
        }
        control.ulcConfirm = enabled
    }

    // MARK: 国家 / 地图

    func setCountry(_ index: Int) async {
        await run("国家覆盖") { try await self.api.post("/api/country/update", form: ["countryMode": "\(index)"]) }
        control.countryIndex = index
    }

    func setMapRegion(_ index: Int) async {
        await run("地图区域") { try await self.api.post("/api/country/update", form: ["mapMode": "\(index)"]) }
        control.mapIndex = index
    }

    // MARK: 系统

    func saveBaseURL(_ raw: String) async {
        api.baseURLString = raw
        system.baseURL = api.baseURLString
        isTesting = true
        do {
            _ = try await api.get("/api/profile/status")
            isConnected = true
            connectionMessage = ""
            showToast("连接成功")
            await refreshSlow()
        } catch {
            isConnected = false
            connectionMessage = error.localizedDescription
            alertMessage = error.localizedDescription
        }
        isTesting = false
    }

    func resetBaseURL() {
        api.baseURLString = APIClient.defaultBase
        system.baseURL = api.baseURLString
        showToast("已恢复 \(APIClient.defaultBase)")
    }

    func runSelfChecks() async {
        isTesting = true
        var results: [SelfCheckItem] = []
        selfChecks = []
        let checks: [(String, String, [String: String])] = [
            ("设备配置 /api/profile/status", "/api/profile/status", [:]),
            ("实时快照 /api/snapshot", "/api/snapshot", ["groups": "home-fast"]),
            ("系统统计 /api/system/stats", "/api/system/stats", [:]),
            ("Wi-Fi 状态 /api/wifi/status", "/api/wifi/status", [:]),
            ("OTA 状态 /api/ota/status", "/api/ota/status", [:])
        ]
        for check in checks {
            do {
                _ = try await api.get(check.1, query: check.2)
                results.append(SelfCheckItem(name: check.0, ok: true, detail: "200 OK"))
            } catch {
                results.append(SelfCheckItem(name: check.0, ok: false, detail: error.localizedDescription))
            }
            selfChecks = results
        }
        isTesting = false
    }

    func applyWiFi(ssid: String, password: String) async {
        let trimmed = ssid.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            alertMessage = "请填写 SSID"
            return
        }
        if !password.isEmpty && (password.count < 8 || password.count > 63) {
            alertMessage = "密码需 8-63 位，留空表示沿用原密码"
            return
        }
        var form = ["ssid": trimmed]
        if !password.isEmpty { form["password"] = password }
        await run("修改热点", target: .none) { try await self.api.post("/api/wifi/apply", form: form) }
        isConnected = false
        connectionMessage = "热点正在重建，请连接新的 SSID 后回到 App"
    }

    func uploadFirmware(from url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        busyAction = "OTA 上传"
        do {
            let data = try Data(contentsOf: url)
            guard data.count > 1_024 else {
                throw APIError.decoding("文件过小，可能不是固件")
            }
            ota = OTAState(fileName: url.lastPathComponent,
                           fileSize: Fmt.bytes(data.count),
                           running: true,
                           progress: 0,
                           stage: "上传中…",
                           received: "-",
                           total: Fmt.bytes(data.count))
            _ = try await api.uploadFirmware(fileName: url.lastPathComponent, data: data)
            ota.stage = "设备校验中…"
            ota.progress = 100
            busyAction = nil
            await pollOTAStatus()
        } catch {
            ota.running = false
            ota.stage = "失败"
            alertMessage = error.localizedDescription
            busyAction = nil
        }
    }

    func pollOTAStatus() async {
        for _ in 0..<90 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let status = (try? await api.get("/api/ota/status")) ?? .empty
            let received = status.int("receivedBytes") ?? 0
            let total = status.int("totalBytes") ?? 0
            ota.received = Fmt.bytes(received)
            ota.total = Fmt.bytes(total)
            if let stage = status.str("stage"), !stage.isEmpty {
                ota.stage = stage
            }
            if status.bool("inProgress") == false {
                ota.running = false
                if status.bool("ok") == true {
                    ota.progress = 100
                    ota.stage = "升级成功，设备重启中"
                    showToast("OTA 成功")
                    isConnected = false
                    connectionMessage = "设备正在重启"
                } else {
                    let reason = status.str("error") ?? "updateError \(status.int("updateError") ?? 0)"
                    ota.stage = "失败：\(reason)"
                    alertMessage = "OTA 失败：\(reason)"
                }
                return
            }
        }
        ota.running = false
        ota.stage = "状态轮询超时"
    }

    func reboot() async {
        await run("重启设备", target: .none) { try await self.api.post("/api/system/reboot") }
        isConnected = false
        connectionMessage = "设备正在重启"
    }

    func factoryReset() async {
        await run("恢复出厂设置", target: .none) { try await self.api.post("/api/system/factory-reset") }
        isConnected = false
        connectionMessage = "已恢复出厂，设备重启后进入 SAFE SETUP MODE"
    }

    func resetSettings() async {
        await run("重置固件设置", target: .none) { try await self.api.post("/api/system/reset-settings") }
        isConnected = false
        connectionMessage = "设置已重置，设备重启中"
    }

    func resetStats() async {
        await run("清零统计", target: .slow) { try await self.api.post("/api/system/reset-stats") }
    }

    func reinitCAN() async {
        await run("重初始化 CAN", target: .slow) { try await self.api.post("/api/system/reinit-can") }
    }

    // MARK: 诊断

    func diagnosticsText() -> String {
        var lines: [String] = []
        lines.append("P4-CAN iOS 诊断")
        lines.append("地址: \(api.baseURLString)")
        lines.append("连接: \(isConnected ? "在线" : "离线 \(connectionMessage)")")
        lines.append("固件: \(overview.firmware)")
        lines.append("车型: \(overview.profileName) / \(overview.topology)")
        lines.append("运行: \(overview.uptime) 空闲: \(overview.heap) 最低: \(overview.minHeap)")
        for bus in buses {
            lines.append("CAN\(bus.id) \(bus.name): \(bus.stateName) rx=\(bus.rx) tx=\(bus.txOk)/\(bus.txFail) off=\(bus.busOff) tec=\(bus.tec) rec=\(bus.rec) age=\(bus.age)")
        }
        lines.append("更新时间: \(overview.updated)")
        return lines.joined(separator: "\n")
    }

    func copyDiagnostics() {
        UIPasteboard.general.string = diagnosticsText()
        showToast("诊断信息已复制")
    }
}
