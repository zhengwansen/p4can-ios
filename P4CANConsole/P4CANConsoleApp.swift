import SwiftUI

@main
struct P4CANConsoleApp: App {
    @StateObject private var model = DeviceModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { await model.start() }
        }
    }
}
