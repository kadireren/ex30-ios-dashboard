import SwiftUI

struct SportOneDashboardView: View {
    @EnvironmentObject private var telemetry: TelemetryStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let torque = telemetry.value(.torque)
        let hp = telemetry.value(.mechanicalPower)
        let speed = telemetry.value(.speed)
        let displayedInstant = telemetry.displayInstantKwhPer100Km
        GeometryReader { geometry in
            let sideWidth = min(190, max(140, geometry.size.width * 0.23))
            let sideHeight = min(geometry.size.height * 0.88, sideWidth * 1.2)
            let speedSize = min(82, max(52, geometry.size.height * 0.26))
            let ringDiameter = min(260, max(160, geometry.size.width * 0.30),
                                   geometry.size.height * 0.72)
            HStack(alignment: .center, spacing: 8) {
                if telemetry.visibleSensors.contains(.torque) {
                    SportCard(title: "ERAD TORQUE", value: torque, unit: "Nm", color: .orange,
                              progress: abs(torque ?? 0) / 400, ring: true,
                              width: sideWidth, height: sideHeight)
                }
                VStack(spacing: 0) {
                    if telemetry.visibleSensors.contains(.speed) {
                        Text(speed.map { String(Int($0.rounded())) } ?? "--")
                            .font(.system(size: speedSize, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                        Text("km/h")
                            .font(.system(size: max(13, speedSize * 0.2)))
                            .foregroundStyle(.primary.opacity(0.62))
                    }
                    Spacer(minLength: 4)
                    if telemetry.visibleSensors.contains(.power) {
                        let consumptionColor = (displayedInstant ?? 0) < 0
                            ? Color.cyan : Color(red: 1, green: 0.38, blue: 0.2)
                        InstantConsumptionRing(
                            kwh100: displayedInstant,
                            color: consumptionColor,
                            diameter: ringDiameter,
                            ringWidth: max(11, ringDiameter * 0.055),
                            valueFontSize: max(18, ringDiameter * 0.09),
                            unitFontSize: max(11, ringDiameter * 0.05)
                        )
                    }
                    Spacer(minLength: 4)
                    FooterMetrics(soc: telemetry.value(.soc), odometer: telemetry.value(.odometer),
                                  range: telemetry.value(.range), visibleSensors: telemetry.visibleSensors)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if telemetry.visibleSensors.contains(.mechanicalPower) {
                    SportCard(title: "ERAD MECH POWER", value: hp, unit: "hp",
                              color: Color(red: 1, green: 0.35, blue: 0.2),
                              progress: abs(hp ?? 0) / 200, ring: false,
                              width: sideWidth, height: sideHeight)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(width: geometry.size.width, height: geometry.size.height)
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
    var width: CGFloat = 190
    var height: CGFloat = 230

    var body: some View {
        let ringSize = min(width - 30, height * 0.55)
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: max(10, width * 0.068), weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if ring {
                ZStack {
                    RingGauge(progress: progress, color: color, width: max(9, ringSize * 0.09))
                    VStack(spacing: 0) {
                        Text(value.map { String(format: "%+.0f", $0) } ?? "--")
                            .font(.system(size: max(20, ringSize * 0.2), weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(unit).font(.caption).foregroundStyle(.primary.opacity(0.65))
                    }
                }.frame(width: ringSize, height: ringSize)
            } else {
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value.map { String(format: "%+.0f", $0) } ?? "--")
                        .font(.system(size: max(22, width * 0.14), weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(unit).foregroundStyle(.primary.opacity(0.65))
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.13))
                        RoundedRectangle(cornerRadius: 4).fill(color)
                            .frame(width: geometry.size.width * progress.clamped(0...1))
                    }
                }.frame(height: 16)
                Spacer(minLength: 4)
            }
        }
        .padding(10)
        .frame(width: width, height: height)
        .background(colorScheme == .dark ? Color(red: 0.03, green: 0.045, blue: 0.055) : Color.white,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2), lineWidth: 2))
    }
}
