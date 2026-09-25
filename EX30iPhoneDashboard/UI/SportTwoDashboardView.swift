import SwiftUI

struct SportTwoDashboardView: View {
    @EnvironmentObject private var telemetry: TelemetryStore

    var body: some View {
        let speed = telemetry.value(.speed)
        let torque = telemetry.value(.torque)
        let hp = telemetry.value(.mechanicalPower)
        let power = telemetry.value(.power)
        let displayedPower = power.map { $0.clamped(-99.9...99.9) }
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                if telemetry.visibleSensors.contains(.speed) {
                    VStack(spacing: 0) {
                        Text(speed.map { String(Int($0.rounded())) } ?? "--")
                            .font(.system(size: 88, weight: .thin, design: .rounded)).monospacedDigit()
                        Text("km/h").font(.system(size: 18)).foregroundStyle(.primary.opacity(0.65))
                    }
                    .frame(width: 205)
                }
                if telemetry.visibleSensors.contains(.power) {
                    ZStack {
                        RingGauge(progress: abs(displayedPower ?? 0) / 99.9,
                                  color: (displayedPower ?? 0) < 0 ? .cyan : Color(red: 1, green: 0.38, blue: 0.2), width: 14)
                            .frame(width: 220, height: 135)
                            .rotationEffect(.degrees(40))
                        Text(displayedPower.map { String(format: "%+.1f kW", $0) } ?? "-- kW")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle((displayedPower ?? 0) < 0 ? .cyan : Color(red: 1, green: 0.38, blue: 0.2))
                            .offset(y: 18)
                    }
                    .frame(width: 220)
                }
                VStack(spacing: 10) {
                    if telemetry.visibleSensors.contains(.torque) {
                        HorizontalMetricCard(title: "ERAD TORQUE", value: torque, unit: "Nm", color: .orange,
                                             progress: abs(torque ?? 0) / 400)
                    }
                    if telemetry.visibleSensors.contains(.mechanicalPower) {
                        HorizontalMetricCard(title: "ERAD MECH POWER", value: hp, unit: "hp",
                                             color: Color(red: 1, green: 0.35, blue: 0.2),
                                             progress: abs(hp ?? 0) / 270)
                    }
                }
                .frame(width: 220)
            }
            Spacer()
            FooterMetrics(soc: telemetry.value(.soc), odometer: telemetry.value(.odometer),
                          range: telemetry.value(.range), visibleSensors: telemetry.visibleSensors)
                .padding(.horizontal, 28).padding(.bottom, 2)
        }
    }
}

private struct HorizontalMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: Double?
    let unit: String
    let color: Color
    let progress: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary.opacity(0.82))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value.map { String(format: "%+.0f", $0) } ?? "--")
                        .font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(color)
                    Text(unit).font(.caption).foregroundStyle(.primary.opacity(0.7))
                }
            }
            Spacer()
            RingGauge(progress: progress, color: color, width: 8).frame(width: 64, height: 64)
        }
        .padding(.horizontal, 14)
        .frame(height: 92)
        .background(colorScheme == .dark ? Color(red: 0.03, green: 0.04, blue: 0.05) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.22), lineWidth: 1.5))
    }
}
