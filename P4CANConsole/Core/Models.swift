import Foundation

/// 统一的语义色调，视图层负责映射成具体颜色。
enum Tone {
    case ok
    case warn
    case bad
    case idle
    case accent
}

struct OverviewState {
    var profileName = "—"
    var topology = ""
    var canA = "—"
    var canB = "—"
    var extra = "—"
    var turn = ""
    var canBusCount = 3
    var setupMode = false
    var nvsError = false

    var apActive = false
    var noaActive = false
    var torque = "—"
    var handsOn = "—"
    var gear = "—"
    var dasState = "—"
    var displayState = "—"
    var canReinitializing = false

    var r79State = "—"
    var r79Reason = ""
    var apGate = ""
    var r79TxOk = "—"
    var r79TxFail = "—"
    var r79Age = "—"

    var uptime = "—"
    var heap = "—"
    var minHeap = "—"
    var firmware = ""
    var updated = "—"
}

struct BusState: Identifiable {
    let id: Int

    var name = "CAN"
    var stateName = "—"
    var tone: Tone = .idle
    var ready = false
    var online = false
    var trafficText = "—"
    var age = "—"
    var rx = "0"
    var txOk = "0"
    var txFail = "0"
    var busOff = "0"
    var missed = "0"
    var overrun = "0"
    var txPin = "?"
    var rxPin = "?"
    var mode = ""

    var tec = "—"
    var rec = "—"
    var polls = "—"
    var busErrors = "—"
    var arbLost = "—"
    var driverTxFailed = "—"
    var recoveries = "—"
    var recoveryFailures = "—"
    var initResult = ""
    var rxResult = ""
    var statusAge = "—"
}

struct TrafficState {
    var nativeAge = "—"
    var nativeOnline = false
    var twaiAge = "—"
    var twaiOnline = false
    var overflow = "0"
    var overflowAge = "—"
}

struct ControlState {
    var nagEnabled = false
    var nagMethodIndex = 0
    var nagMethodName = ""
    var nagModeIndex = 3

    var blinkEnabled = false
    var blinkDelay = 500.0
    var tlssc = false
    var lab = false

    var dmsEnabled = false
    var dmsSupported = true
    var dmsActive = false
    var isaEnabled = false
    var isaSupported = true
    var isaActive = false

    var ulcAlcOff = false
    var ulcOffIndex = 0
    var ulcBlindIndex = 0
    var ulcTimingIndex = 0
    var ulcConfirm = false
    var ulcRaw = ""

    var countryIndex = 0
    var mapIndex = 0
    var countrySupported = true
    var countryRaw = ""
}

struct SystemState {
    var firmware = "—"
    var profile = "—"
    var uptime = "—"
    var heap = "—"
    var minHeap = "—"
    var baseURL = APIClient.defaultBase
    var wifiSSID = ""
    var wifiIP = ""
    var wifiPasswordIsDefault = false
    var wifiRaw = ""
    var hasWifiStatus = false
}

struct OTAState {
    var fileName = ""
    var fileSize = "-"
    var running = false
    var progress = 0.0
    var stage = "未开始"
    var received = "-"
    var total = "-"
}

struct SelfCheckItem: Identifiable {
    let id = UUID()
    let name: String
    let ok: Bool
    let detail: String
}

// MARK: - 选项常量（取值与固件一致）

enum Options {
    static let nagMethods = [0, 1]
    static let nagMethodLabels = ["力矩注入 (Torque)", "TSL9 输入序列"]

    /// MODE_A=0, MODE_B=1, MODE_C=3, MODE_H=7
    static let nagModes = [0, 1, 3, 7]
    static let nagModeLabels = ["Mode A", "Mode B", "Mode C", "Mode H · 手扶"]

    static let ulcOffValues = ["stock", "0", "1"]
    static let ulcOffLabels = ["原厂 (stock)", "0 · 关闭", "1 · 启用"]

    static let blindValues = ["stock", "0", "1", "2"]
    static let blindLabels = ["原厂 (stock)", "0", "1", "2"]

    static let timingValues = [0, 1]
    static let timingLabels = ["时序 0", "时序 1"]

    static let countryLabels = ["STOCK", "US", "KOREA", "NEW ZEALAND"]
    static let mapLabels = ["STOCK", "US 0", "KR 7"]
}
