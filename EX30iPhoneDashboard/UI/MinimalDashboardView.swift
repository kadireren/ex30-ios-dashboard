import SwiftUI

struct MinimalDashboardView: View {
    @EnvironmentObject private var telemetry: TelemetryStore

    var body: some View {
        let speed = telemetry.value(.speed)
        let displayedInstant = telemetry.displayInstantKwhPer100Km
        GeometryReader { geometry in
            let edgePad: CGFloat = 8
            let speedSize = min(92, max(64, geometry.size.height * 0.28))
            let valueSize = min(28, max(20, geometry.size.height * 0.085))
            VStack(spacing: 0) {
                Spacer(minLength: 2)
                if telemetry.visibleSensors.contains(.speed) {
                    Text(speed.map { String(Int($0.rounded())) } ?? "--")
                        .font(.system(size: speedSize, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("km/h")
                        .font(.system(size: max(13, speedSize * 0.17), weight: .medium))
                        .foregroundStyle(.primary.opacity(0.55))
                }
                Spacer(minLength: 8)
                if telemetry.visibleSensors.contains(.power) {
                    VStack(spacing: 0) {
                        PowerBar(power: displayedInstant)
                            .frame(height: 15)
                        HStack {
                            Text("R E G E N").foregroundStyle(Color.green)
                            Spacer()
                            Text("P O W E R").foregroundStyle(Color.red)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.top, 7)

                        // Barın altında ortalanmış değer; birim değerin hemen altında.
                        Text(InstantConsumptionDisplay.valueText(displayedInstant))
                            .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.84, green: 0.66, blue: 0.29))
                            .padding(.top, 8)
                            .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.38), value: displayedInstant)
                        Text(InstantConsumptionDisplay.unit)
                            .font(.system(size: max(11, valueSize * 0.55), weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.84, green: 0.66, blue: 0.29).opacity(0.75))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, edgePad)
                }
                Spacer(minLength: 6)
                HStack {
                    if telemetry.visibleSensors.contains(.soc) {
                        Label(telemetry.value(.soc).map { "\(Int($0.rounded()))%" } ?? "--%", systemImage: "battery.75percent")
                            .font(MainFooterMetricStyle.socRangeText)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.primary.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    if telemetry.visibleSensors.contains(.odometer) {
                        VStack(spacing: 2) {
                            Text("ODO")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
                            Text(telemetry.value(.odometer).map { String(format: "%.0f", $0) } ?? "--")
                                .font(MainFooterMetricStyle.odoValue)
                                .foregroundStyle(.primary.opacity(0.9))
                        }
                    }
                    Spacer()
                    if telemetry.visibleSensors.contains(.range) {
                        Label(telemetry.value(.range).map { "\(Int($0.rounded())) km" } ?? "-- km", systemImage: "bolt.fill")
                            .font(MainFooterMetricStyle.socRangeText)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.primary.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .padding(.horizontal, edgePad)
                .padding(.bottom, 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.38), value: power)
    }
}
