import SwiftUI

struct ControlView: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "功能控制",
                           subtitle: model.busyAction,
                           connected: model.isConnected,
                           trailing: model.overview.updated)

                if !model.isConnected {
                    Banner(title: "未连接设备", detail: model.connectionMessage, tone: .bad)
                }

                coreCard
                assistCard
                regionCard
                rawCard

                Text("开关即时写入设备 NVS，部分选项需重启生效")
                    .font(.caption2)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .refreshable { await model.refreshSlow() }
    }

    // MARK: - 核心

    private var coreCard: some View {
        Card {
            HStack {
                Text("核心功能")
                    .font(.caption)
                    .kerning(1.2)
                    .foregroundStyle(Theme.muted)
                Spacer()
                TagView(text: model.control.nagEnabled ? "NAG ON" : "NAG OFF",
                        tone: model.control.nagEnabled ? .ok : .idle)
            }

            Toggle(isOn: binding(get: { model.control.nagEnabled },
                                 set: { value in Task { await model.setNAGEnabled(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("方向盘 NAG 抑制").font(.subheadline)
                    Text(model.control.nagMethodName.isEmpty ? "当前注入方法未知" : model.control.nagMethodName)
                        .font(.caption2)
                        .foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.ok)

            DividerLine()

            pickerRow(title: "注入方法",
                      selection: Binding(get: { model.control.nagMethodIndex },
                                         set: { index in Task { await model.setNAGMethod(index) } }),
                      labels: Options.nagMethodLabels)

            DividerLine()

            pickerRow(title: "模式模板",
                      subtitle: "写入该模式默认波形参数",
                      selection: Binding(get: { model.control.nagModeIndex },
                                         set: { index in Task { await model.setNAGMode(index) } }),
                      labels: Options.nagModeLabels)

            DividerLine()

            Toggle(isOn: binding(get: { model.control.blinkEnabled },
                                 set: { value in Task { await model.setBlinkEnabled(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动转向灯 · Advanced EAP").font(.subheadline)
                    Text("NOA 下按导航自动打灯").font(.caption2).foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.ok)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("触发延时").font(.caption).foregroundStyle(Theme.muted)
                    Spacer()
                    Text("\(Int(model.control.blinkDelay)) ms")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                }
                Slider(value: binding(get: { model.control.blinkDelay },
                                      set: { model.control.blinkDelay = $0 }),
                       in: 0...10000,
                       step: 100,
                       onEditingChanged: { editing in
                           guard !editing else { return }
                           let value = Int(model.control.blinkDelay)
                           Task { await model.setBlinkDelay(value) }
                       })
                .tint(Theme.accent)
            }

            DividerLine()

            Toggle(isOn: binding(get: { model.control.tlssc },
                                 set: { value in Task { await model.setTLSSCC(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TLSSC 绿灯起步").font(.subheadline)
                    Text("交通灯 / 停止标志控制").font(.caption2).foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.ok)

            DividerLine()

            Toggle(isOn: binding(get: { model.control.lab },
                                 set: { value in Task { await model.setLAB(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("实验室模式 (LAB)").font(.subheadline)
                    Text("开启抓包缓冲，占用较多内存").font(.caption2).foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.warn)
        }
    }

    // MARK: - 驾驶辅助

    private var assistCard: some View {
        Card("驾驶辅助", hint: (model.control.dmsActive || model.control.isaActive) ? "生效中" : "待命") {
            Toggle(isOn: binding(get: { model.control.dmsEnabled },
                                 set: { value in Task { await model.setDMS(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("驾驶员监控干预").font(.subheadline)
                    Text(model.control.dmsSupported ? "DMS 状态注入" : "当前车型不支持")
                        .font(.caption2)
                        .foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.ok)
            .disabled(!model.control.dmsSupported)

            DividerLine()

            Toggle(isOn: binding(get: { model.control.isaEnabled },
                                 set: { value in Task { await model.setISA(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ISA 提示音抑制").font(.subheadline)
                    Text(model.control.isaSupported ? "限速提示音" : "当前车型不支持")
                        .font(.caption2)
                        .foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.ok)
            .disabled(!model.control.isaSupported)

            DividerLine()

            Toggle(isOn: binding(get: { model.control.ulcAlcOff },
                                 set: { value in Task { await model.setULCAlcOff(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ULC 自动变道").font(.subheadline)
                    Text("高速自动变道辅助").font(.caption2).foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.ok)

            DividerLine()

            pickerRow(title: "ULC Off 模式",
                      selection: Binding(get: { model.control.ulcOffIndex },
                                         set: { index in Task { await model.setULCOff(index) } }),
                      labels: Options.ulcOffLabels)

            DividerLine()

            pickerRow(title: "盲区显示模式",
                      selection: Binding(get: { model.control.ulcBlindIndex },
                                         set: { index in Task { await model.setULCBlind(index) } }),
                      labels: Options.blindLabels)

            DividerLine()

            pickerRow(title: "确认时序",
                      selection: Binding(get: { model.control.ulcTimingIndex },
                                         set: { index in Task { await model.setULCTiming(index) } }),
                      labels: Options.timingLabels)

            DividerLine()

            Toggle(isOn: binding(get: { model.control.ulcConfirm },
                                 set: { value in Task { await model.setULCConfirm(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("免确认变道").font(.subheadline)
                    Text("EU 地区无效，请改用自动转向灯").font(.caption2).foregroundStyle(Theme.dim)
                }
            }
            .tint(Theme.ok)
        }
    }

    // MARK: - 区域

    private var regionCard: some View {
        Card {
            HStack {
                Text("国家 / 地图区域")
                    .font(.caption)
                    .kerning(1.2)
                    .foregroundStyle(Theme.muted)
                Spacer()
                TagView(text: (model.control.countryIndex != 0 || model.control.mapIndex != 0) ? "已覆盖" : "原厂",
                        tone: (model.control.countryIndex != 0 || model.control.mapIndex != 0) ? .warn : .idle)
            }

            pickerRow(title: "国家覆盖",
                      selection: Binding(get: { model.control.countryIndex },
                                         set: { index in Task { await model.setCountry(index) } }),
                      labels: Options.countryLabels,
                      disabled: !model.control.countrySupported)

            DividerLine()

            pickerRow(title: "地图区域",
                      selection: Binding(get: { model.control.mapIndex },
                                         set: { index in Task { await model.setMapRegion(index) } }),
                      labels: Options.mapLabels,
                      disabled: !model.control.countrySupported)

            if !model.control.countrySupported {
                Text("当前车型拓扑不支持国家覆盖")
                    .font(.caption2)
                    .foregroundStyle(Theme.dim)
            }
        }
    }

    // MARK: - 原始状态

    private var rawCard: some View {
        Card("设备原始状态", hint: "核对固件返回值") {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ULC").font(.caption2).foregroundStyle(Theme.dim)
                    Text(model.control.ulcRaw.isEmpty ? "—" : model.control.ulcRaw)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .textSelection(.enabled)
                    Text("国家覆盖").font(.caption2).foregroundStyle(Theme.dim)
                    Text(model.control.countryRaw.isEmpty ? "—" : model.control.countryRaw)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .textSelection(.enabled)
                }
                .padding(.top, 8)
            } label: {
                Text("展开原始 JSON")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
            .tint(Theme.accent)
        }
    }

    // MARK: - 辅助

    private func binding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: set)
    }

    private func pickerRow(title: String, subtitle: String? = nil,
                           selection: Binding<Int>, labels: [String],
                           disabled: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(Theme.text.opacity(0.88))
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 8)
            Picker(title, selection: selection) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label).tag(index)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Theme.accent)
            .disabled(disabled)
        }
        .padding(.vertical, 4)
    }
}

struct ControlView_Previews: PreviewProvider {
    static var previews: some View {
        ControlView()
            .environmentObject(DeviceModel())
            .preferredColorScheme(.dark)
    }
}
