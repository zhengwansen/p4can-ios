import SwiftUI

enum Theme {
    static let bg = Color(red: 0.027, green: 0.043, blue: 0.071)
    static let card = Color(red: 0.063, green: 0.102, blue: 0.169)
    static let inset = Color(red: 0.051, green: 0.086, blue: 0.149)
    static let line = Color(red: 0.118, green: 0.173, blue: 0.259)
    static let text = Color(red: 0.902, green: 0.929, blue: 0.969)
    static let muted = Color(red: 0.545, green: 0.608, blue: 0.706)
    static let dim = Color(red: 0.420, green: 0.482, blue: 0.576)
    static let accent = Color(red: 0.298, green: 0.761, blue: 1.0)
    static let ok = Color(red: 0.239, green: 0.863, blue: 0.592)
    static let warn = Color(red: 1.0, green: 0.714, blue: 0.282)
    static let bad = Color(red: 1.0, green: 0.361, blue: 0.478)
}

extension Tone {
    var color: Color {
        switch self {
        case .ok: return Theme.ok
        case .warn: return Theme.warn
        case .bad: return Theme.bad
        case .idle: return Theme.muted
        case .accent: return Theme.accent
        }
    }
}

// MARK: - 基础组件

struct Card<Content: View>: View {
    private let title: String?
    private let hint: String?
    private let content: Content

    init(_ title: String? = nil, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || hint != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title)
                            .font(.caption)
                            .kerning(1.2)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    if let hint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(Theme.dim)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct InfoRow: View {
    let label: String
    var sub: String?
    let value: String
    var mono: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.text.opacity(0.88))
                if let sub {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }
}

struct StatCell: View {
    let label: String
    let value: String
    var unit: String?
    var small: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.dim)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(small ? .title3 : .title2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(Theme.dim)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.inset))
    }
}

struct TagView: View {
    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tone.color)
            .background(Capsule().fill(tone.color.opacity(0.15)))
    }
}

struct Banner: View {
    let title: String
    var detail: String?
    let tone: Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(tone.color.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tone.color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(tone.color.opacity(0.35), lineWidth: 1))
        .foregroundStyle(tone.color)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String?
    let connected: Bool
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(connected ? Theme.ok : Theme.bad)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

/// 主按钮样式
struct PrimaryButtonStyle: ButtonStyle {
    var tone: Tone = .accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tone.color.opacity(configuration.isPressed ? 0.28 : 0.18)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(tone.color.opacity(0.45), lineWidth: 1))
            .foregroundStyle(tone.color)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.inset.opacity(configuration.isPressed ? 0.6 : 1)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .foregroundStyle(Theme.text.opacity(0.9))
    }
}

/// 深色页面背景
struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
    }
}

extension View {
    func pageBackground() -> some View { modifier(PageBackground()) }
}
