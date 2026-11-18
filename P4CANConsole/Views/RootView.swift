import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("总览", systemImage: "car.fill") }

            ControlView()
                .tabItem { Label("控制", systemImage: "switch.2") }

            CANView()
                .tabItem { Label("总线", systemImage: "cable.connector") }

            SystemView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Text(toast)
                    .font(.footnote)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.card))
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    .foregroundStyle(Theme.text)
                    .padding(.bottom, 68)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.toast)
        .alert("提示", isPresented: alertBinding) {
            Button("好", role: .cancel) { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { presented in if !presented { model.alertMessage = nil } }
        )
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(DeviceModel())
            .preferredColorScheme(.dark)
    }
}
