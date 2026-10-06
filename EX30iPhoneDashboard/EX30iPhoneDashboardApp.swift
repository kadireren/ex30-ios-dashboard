import SwiftUI

@main
struct EX30iPhoneDashboardApp: App {
    @StateObject private var telemetry = TelemetryStore()

    var body: some Scene {
        WindowGroup {
            DashboardRootView()
                .environmentObject(telemetry)
                .preferredColorScheme(.dark)
                .onAppear {
                    telemetry.start()
                }
                .onDisappear {
                    telemetry.stop()
                }
        }
    }
}
