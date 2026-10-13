import SwiftUI

struct SportTwoDashboardView: View {
    @EnvironmentObject private var telemetry: TelemetryStore

    var body: some View {
        let speed = telemetry.value(.speed)
        let torque = telemetry.value(.torque)
        let hp = telemetry.value(.mechanicalPower)
        let displayedInstant = telemetry.displayInstantKwhPer100Km
        GeometryReader { geometry in
            let edgePad: CGFloat = 4
            let colGap: CGFloat = 8
            let usableWidth = geometry.size.width - edgePad * 2 - colGap * 2
            let speedCol = usableWidth * 0.24
            let ringCol = usableWidth * 0.36
            let cardCol = usableWidth * 0.40
            let speedSize = min(88, max(52, geometry.size.height * 0.32))
            let ringDiameter = min(ringCol * 0.98, geometry.size.height * 0.68)
            let cardHeight = min(96, max(72, (geometry.size.height - 28) * 0.40))
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: colGap) {
                    if telemetry.visibleSensors.contains(.speed) {
                        VStack(spacing: 0) {
                            Text(speed.map { String(Int($0.rounded())) } ?? "--")
                                .font(.system(size: speedSize, weight: .thin, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.65)
                                .lineLimit(1)
                            Text("km/h")
                                .font(.system(size: max(13, speedSize * 0.2)))
                                .foregroundStyle(.primary.opacity(0.65))
                        }
                        .frame(width: speedCol)
                    }
                    if telemetry.visibleSensors.contains(.power) {
                        let consumptionColor = (displayedInstant ?? 0) < 0
                            ? Color.cyan : Color(red: 1, green: 0.38, blue: 0.2)
                        InstantConsumptionRing(
                            kwh100: displayedInstant,
                            color: consumptionColor,
                            diameter: ringDiameter,
                            ringWidth: max(11, ringDiameter * 0.06),
                            valueFontSize: max(17, ringDiameter * 0.095),
                            unitFontSize: max(10, ringDiameter * 0.055)
                        )
                        .frame(width: ringCol)
                    }
                    VStack(spacing: 8) {
                        if telemetry.visibleSensors.contains(.torque) {
                            HorizontalMetricCard(title: "ERAD TORQUE", value: torque, unit: "Nm",
                                                 color: .orange, progress: abs(torque ?? 0) / 400,
                                                 height: cardHeight)
                        }
                        if telemetry.visibleSensors.contains(.mechanicalPower) {
                            HorizontalMetricCard(title: "ERAD MECH POWER", value: hp, unit: "hp",
                                                 color: Color(red: 1, green: 0.35, blue: 0.2),
                                                 progress: abs(hp ?? 0) / 270,
                                                 height: cardHeight)
                        }
                    }
                    .frame(width: cardCol)
                }
                .padding(.horizontal, edgePad)
                .frame(maxHeight: .infinity)
                FooterMetrics(soc: telemetry.value(.soc), odometer: telemetry.value(.odometer),
                              range: telemetry.value(.range), visibleSensors: telemetry.visibleSensors)
                    .padding(.horizontal, edgePad)
                    .padding(.bottom, 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
    var height: CGFloat = 92

    var body: some View {
        let ringSize = min(64, height * 0.7)
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: max(10, height * 0.13), weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value.map { String(format: "%+.0f", $0) } ?? "--")
                        .font(.system(size: max(20, height * 0.28), weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(unit).font(.caption).foregroundStyle(.primary.opacity(0.7))
                }
            }
            Spacer(minLength: 4)
            RingGauge(progress: progress, color: color, width: max(6, ringSize * 0.12))
                .frame(width: ringSize, height: ringSize)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .background(colorScheme == .dark ? Color(red: 0.03, green: 0.04, blue: 0.05) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.22), lineWidth: 1.5))
    }
}
