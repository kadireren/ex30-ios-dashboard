import SwiftUI

struct SportTwoDashboardView: View {
    @EnvironmentObject private var telemetry: TelemetryStore

    var body: some View {
        let speed = telemetry.value(.speed)
        let torque = telemetry.value(.torque)
        let hp = telemetry.value(.mechanicalPower)
        let power = telemetry.value(.power)
        VStack(spacing: 0) {
            Spacer().frame(height: 45)
            HStack(alignment: .top, spacing: 34) {
                if telemetry.visibleSensors.contains(.speed) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(speed.map { String(Int($0.rounded())) } ?? "--")
                            .font(.system(size: 116, weight: .thin, design: .rounded)).monospacedDigit()
                        Text("km/h").font(.system(size: 18)).foregroundStyle(.primary.opacity(0.65))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(maxWidth: 320)
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
                .frame(maxWidth: 390)
            }
            .padding(.horizontal, 30)
            if telemetry.visibleSensors.contains(.power) {
                ZStack {
                    RingGauge(progress: abs(power ?? 0) / 100,
                              color: (power ?? 0) < 0 ? .cyan : Color(red: 1, green: 0.38, blue: 0.2), width: 17)
                        .frame(width: 520, height: 185)
                        .rotationEffect(.degrees(40))
                    Text(power.map { String(format: "%+.0f kW", $0) } ?? "-- kW")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle((power ?? 0) < 0 ? .cyan : Color(red: 1, green: 0.38, blue: 0.2))
                        .offset(y: 24)
                }
                .frame(height: 120)
            }
            Spacer()
            FooterMetrics(soc: telemetry.value(.soc), odometer: telemetry.value(.odometer),
                          range: telemetry.value(.range), visibleSensors: telemetry.visibleSensors)
                .padding(.horizontal, 28).padding(.bottom, 18)
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
            RingGauge(progress: progress, color: color, width: 10).frame(width: 90, height: 90)
        }
        .padding(.horizontal, 18)
        .frame(height: 118)
        .background(colorScheme == .dark ? Color(red: 0.03, green: 0.04, blue: 0.05) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.22), lineWidth: 1.5))
    }
}
