import SwiftUI

struct GaugeArc: Shape {
    var progress: Double
    var startAngle: Angle = .degrees(140)
    var endAngle: Angle = .degrees(400)

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let end = startAngle.degrees + (endAngle.degrees - startAngle.degrees) * min(max(progress, 0), 1)
        path.addArc(center: center, radius: radius, startAngle: startAngle,
                    endAngle: .degrees(end), clockwise: false)
        return path
    }
}

struct RingGauge: View {
    let progress: Double
    let color: Color
    let width: CGFloat

    var body: some View {
        ZStack {
            GaugeArc(progress: 1).stroke(Color(red: 0.18, green: 0.22, blue: 0.25),
                                         style: StrokeStyle(lineWidth: width, lineCap: .round))
            GaugeArc(progress: progress).stroke(color,
                                                style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        .padding(width / 2)
        .animation(.linear(duration: 0.12), value: progress)
    }
}

enum InstantConsumptionDisplay {
    static let unit = "kWh/100 km"

    static func valueText(_ kwh100: Double?) -> String {
        guard let kwh100, kwh100.isFinite else { return "--" }
        return String(format: "%+.1f", min(max(kwh100, -99.9), 99.9))
    }

    /// Eski kW sayı slotu: aynı satırda ham anlık tüketim + birim.
    static func powerSlotLabel(_ kwh100: Double?) -> String {
        "\(valueText(kwh100)) \(unit)"
    }
}

/// Sport temaları: yarım halka + değer (açık ağızda); birim değerin altında (çakışmasız).
struct InstantConsumptionRing: View {
    let kwh100: Double?
    let color: Color
    var diameter: CGFloat = 220
    var ringWidth: CGFloat = 14
    var valueFontSize: CGFloat = 22
    var unitFontSize: CGFloat = 12

    private var halfHeight: CGFloat { diameter * 0.56 }

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                RingGauge(progress: abs(kwh100 ?? 0) / 99.9, color: color, width: ringWidth)
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.degrees(40))
                    .frame(width: diameter, height: halfHeight, alignment: .top)
                    .clipped()

                Text(InstantConsumptionDisplay.valueText(kwh100))
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.bottom, halfHeight * 0.08)
                    .animation(.easeOut(duration: 0.14), value: kwh100)
            }
            .frame(width: diameter, height: halfHeight)

            Text(InstantConsumptionDisplay.unit)
                .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(color.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: diameter)
    }
}

/// Yarım halka + değer (açık ağızda) + birim (halkanın altında). Offset ile taşma yok.
struct InstantConsumptionGauge: View {
    let kwh100: Double?
    let color: Color
    var diameter: CGFloat = 220
    var lineWidth: CGFloat = 14
    var valueFontSize: CGFloat = 22

    private var halfHeight: CGFloat { diameter * 0.56 }

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                RingGauge(progress: abs(kwh100 ?? 0) / 99.9, color: color, width: lineWidth)
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.degrees(40))
                    .frame(width: diameter, height: halfHeight, alignment: .top)
                    .clipped()

                Text(InstantConsumptionDisplay.valueText(kwh100))
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.bottom, halfHeight * 0.08)
                    .animation(.easeOut(duration: 0.14), value: kwh100)
            }
            .frame(width: diameter, height: halfHeight)

            Text(InstantConsumptionDisplay.unit)
                .font(.system(size: max(11, valueFontSize * 0.55), weight: .medium, design: .rounded))
                .foregroundStyle(color.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: diameter)
    }
}

enum MainFooterMetricStyle {
    static let socRangeText = Font.system(size: 19, weight: .medium, design: .rounded)
    static let odoValue = Font.system(size: 19, weight: .medium, design: .rounded)
}

struct FooterMetrics: View {
    let soc: Double?
    let odometer: Double?
    let range: Double?
    let visibleSensors: Set<SensorKey>

    var body: some View {
        HStack {
            if visibleSensors.contains(.soc) {
                Label(soc.map { "SOC \(Int($0.rounded()))%" } ?? "SOC --%", systemImage: "battery.75percent")
                    .font(MainFooterMetricStyle.socRangeText)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            if visibleSensors.contains(.odometer) {
                VStack(spacing: 1) {
                    Text("ODO")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.45))
                    Text(odometer.map { String(format: "%.0f", $0) } ?? "--")
                        .font(MainFooterMetricStyle.odoValue)
                        .foregroundStyle(.primary.opacity(0.9))
                        .monospacedDigit()
                }
            }
            Spacer()
            if visibleSensors.contains(.range) {
                Label(range.map { "\(Int($0.rounded())) km" } ?? "-- km", systemImage: "bolt.fill")
                    .font(MainFooterMetricStyle.socRangeText)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}
