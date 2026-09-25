import SwiftUI

struct MinimalDashboardView: View {
    @EnvironmentObject private var telemetry: TelemetryStore

    var body: some View {
        let speed = telemetry.value(.speed)
        let power = telemetry.value(.power)
        let displayedPower = power.map { $0.clamped(-99.9...99.9) }
        VStack(spacing: 0) {
            Spacer(minLength: 4)
            if telemetry.visibleSensors.contains(.speed) {
                Text(speed.map { String(Int($0.rounded())) } ?? "--")
                    .font(.system(size: 92, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/h").font(.system(size: 16, weight: .medium)).foregroundStyle(.primary.opacity(0.55))
            }
            Spacer().frame(height: 14)
            if telemetry.visibleSensors.contains(.power) {
                PowerBar(power: displayedPower).frame(maxWidth: 610)
                HStack {
                    Text("R E G E N").foregroundStyle(Color.green)
                    Spacer()
                    Text("P O W E R").foregroundStyle(Color.red)
                }
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: 610)
                .padding(.top, 7)
                Text(displayedPower.map { String(format: "%+.1f kW", $0) } ?? "-- kW")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.84, green: 0.66, blue: 0.29))
                    .padding(.top, 8)
            }
            Spacer()
            HStack {
                if telemetry.visibleSensors.contains(.soc) {
                    Label(telemetry.value(.soc).map { "\(Int($0.rounded()))%" } ?? "--%", systemImage: "battery.75percent")
                }
                Spacer()
                if telemetry.visibleSensors.contains(.odometer) {
                    VStack(spacing: 2) {
                        Text("ODO").font(.caption2).foregroundStyle(.primary.opacity(0.5))
                        Text(telemetry.value(.odometer).map { String(format: "%.0f", $0) } ?? "--")
                    }
                }
                Spacer()
                if telemetry.visibleSensors.contains(.range) {
                    Label(telemetry.value(.range).map { "\(Int($0.rounded())) km" } ?? "-- km", systemImage: "bolt.fill")
                }
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, 28)
            .padding(.bottom, 2)
        }
    }
}

private struct PowerBar: View {
    let power: Double?

    var body: some View {
        GeometryReader { geometry in
            let half = geometry.size.width / 2
            let normalized = (power ?? 0).clamped(-99.9...99.9) / 99.9
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.11))
                Rectangle().fill(Color.primary.opacity(0.4)).frame(width: 2)
                if normalized < 0 {
                    RoundedRectangle(cornerRadius: 3).fill(Color.green)
                        .frame(width: half * -normalized)
                        .offset(x: -half * -normalized / 2)
                } else {
                    RoundedRectangle(cornerRadius: 3).fill(Color.red)
                        .frame(width: half * normalized)
                        .offset(x: half * normalized / 2)
                }
            }
        }
        .frame(height: 15)
        .animation(.linear(duration: 0.12), value: power)
    }
}
