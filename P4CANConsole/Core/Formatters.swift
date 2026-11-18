import Foundation

enum Fmt {
    /// 固件用 999999 表示「从未发生」
    static func age(_ ms: Int?) -> String {
        guard let ms, ms < 999_999 else { return "—" }
        if ms < 1_000 { return "\(ms) ms" }
        if ms < 60_000 { return String(format: "%.1f s", Double(ms) / 1_000) }
        return "\(ms / 60_000) min"
    }

    static func bytes(_ value: Int?) -> String {
        guard let value, value > 0 else { return "0 B" }
        if value < 1_024 { return "\(value) B" }
        if value < 1_048_576 { return String(format: "%.1f KB", Double(value) / 1_024) }
        return String(format: "%.2f MB", Double(value) / 1_048_576)
    }

    static func duration(_ seconds: Int?) -> String {
        guard let seconds, seconds >= 0 else { return "—" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        let secs = seconds % 60
        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        if minutes > 0 { return "\(minutes) 分 \(secs) 秒" }
        return "\(secs) 秒"
    }

    static func torque(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    static func count(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }

    static func twaiState(_ value: Int?) -> String {
        switch value {
        case 0: return "STOPPED"
        case 1: return "RUNNING"
        case 2: return "BUS-OFF"
        case 3: return "RECOVERING"
        case .some(let other): return "STATE \(other)"
        case .none: return "—"
        }
    }

    static func twaiTone(_ value: Int?) -> Tone {
        switch value {
        case 1: return .ok
        case 2: return .bad
        case 3: return .warn
        default: return .idle
        }
    }

    static func clock(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
