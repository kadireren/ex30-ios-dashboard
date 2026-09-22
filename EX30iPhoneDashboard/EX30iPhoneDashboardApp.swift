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
                    UIApplication.shared.isIdleTimerDisabled = true
                    telemetry.start()
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                    telemetry.stop()
                }
        }
    }
}
