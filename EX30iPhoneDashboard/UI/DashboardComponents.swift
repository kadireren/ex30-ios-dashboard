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

struct FooterMetrics: View {
    let soc: Double?
    let odometer: Double?
    let range: Double?
    let visibleSensors: Set<SensorKey>

    var body: some View {
        HStack {
            if visibleSensors.contains(.soc) {
                Label(soc.map { "SOC \(Int($0.rounded()))%" } ?? "SOC --%", systemImage: "battery.75percent")
                    .foregroundStyle(Color.cyan)
            }
            Spacer()
            if visibleSensors.contains(.odometer) {
                VStack(spacing: 1) {
                    Text("ODO")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.45))
                    Text(odometer.map { String(format: "%.0f", $0) } ?? "--")
                        .foregroundStyle(.primary.opacity(0.9))
                        .monospacedDigit()
                }
            }
            Spacer()
            if visibleSensors.contains(.range) {
                Label(range.map { "\(Int($0.rounded())) km" } ?? "-- km", systemImage: "bolt.fill")
                    .foregroundStyle(.primary.opacity(0.9))
            }
        }
        .font(.system(size: 16, weight: .medium, design: .rounded))
    }
}

extension Double {
    func clamped(_ limits: ClosedRange<Double>) -> Double {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
