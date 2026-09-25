import SwiftUI

struct SportOneDashboardView: View {
    @EnvironmentObject private var telemetry: TelemetryStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let torque = telemetry.value(.torque)
        let hp = telemetry.value(.mechanicalPower)
        let speed = telemetry.value(.speed)
        let power = telemetry.value(.power)
        ZStack {
            HStack {
                if telemetry.visibleSensors.contains(.torque) {
                    SportCard(title: "ERAD TORQUE", value: torque, unit: "Nm", color: .orange,
                              progress: abs(torque ?? 0) / 400, ring: true)
                }
                Spacer(minLength: 290)
                if telemetry.visibleSensors.contains(.mechanicalPower) {
                    SportCard(title: "ERAD MECH POWER", value: hp, unit: "hp",
                              color: Color(red: 1, green: 0.35, blue: 0.2),
                              progress: abs(hp ?? 0) / 200, ring: false)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            VStack(spacing: 0) {
                if telemetry.visibleSensors.contains(.speed) {
                    Text(speed.map { String(Int($0.rounded())) } ?? "--")
                        .font(.system(size: 82, weight: .thin, design: .rounded)).monospacedDigit()
                    Text("km/h").font(.system(size: 17)).foregroundStyle(.primary.opacity(0.62))
                }
                Spacer()
                if telemetry.visibleSensors.contains(.power) {
                    RingGauge(progress: abs(power ?? 0) / 100,
                              color: (power ?? 0) < 0 ? .cyan : Color(red: 1, green: 0.38, blue: 0.2), width: 15)
                        .frame(width: 260, height: 125)
                        .rotationEffect(.degrees(40))
                    Text(power.map { String(format: "%+.0f kW", $0) } ?? "-- kW")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle((power ?? 0) < 0 ? .cyan : Color(red: 1, green: 0.38, blue: 0.2))
                        .offset(y: -48)
                }
                FooterMetrics(soc: telemetry.value(.soc), odometer: telemetry.value(.odometer),
                              range: telemetry.value(.range), visibleSensors: telemetry.visibleSensors)
                    .padding(.horizontal, 28).padding(.bottom, 2)
            }
        }
    }
}

private struct SportCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: Double?
    let unit: String
    let color: Color
    let progress: Double
    let ring: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary.opacity(0.8))
            if ring {
                ZStack {
                    RingGauge(progress: progress, color: color, width: 12)
                    VStack(spacing: 0) {
                        Text(value.map { String(format: "%+.0f", $0) } ?? "--")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text(unit).font(.caption).foregroundStyle(.primary.opacity(0.65))
                    }
                }.frame(width: 135, height: 135)
            } else {
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value.map { String(format: "%+.0f", $0) } ?? "--")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(unit).foregroundStyle(.primary.opacity(0.65))
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.13))
                        RoundedRectangle(cornerRadius: 4).fill(color)
                            .frame(width: geometry.size.width * progress.clamped(0...1))
                    }
                }.frame(height: 18)
                Spacer()
            }
        }
        .padding(13)
        .frame(width: 190, height: 230)
        .background(colorScheme == .dark ? Color(red: 0.03, green: 0.045, blue: 0.055) : Color.white,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2), lineWidth: 2))
    }
}
