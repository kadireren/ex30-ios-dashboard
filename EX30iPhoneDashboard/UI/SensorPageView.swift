import SwiftUI

struct SensorPageView: View {
    @EnvironmentObject private var telemetry: TelemetryStore
    @Environment(\.colorScheme) private var colorScheme
    let page: DashboardPage

    private var sensors: [SensorKey] {
        SensorKey.allCases.filter { $0.page == page && telemetry.visibleSensors.contains($0) }
    }

    private var columnCount: Int {
        page == .performance ? 3 : 4
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount)
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(sensors, id: \.self) { key in
                    SensorCard(key: key, value: telemetry.value(key))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            Spacer(minLength: 6)
        }
        .overlay {
            if sensors.isEmpty {
                Text("Bu sayfada görünür sensör yok")
                    .foregroundStyle(.primary.opacity(0.55))
            }
        }
    }
}

private struct SensorCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let key: SensorKey
    let value: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(key.title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedValue)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                Text(key.unit)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.58))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 98, maxHeight: 108)
        .background(colorScheme == .dark ? Color(red: 0.035, green: 0.048, blue: 0.058) : Color.white,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.14), lineWidth: 1))
    }

    private var formattedValue: String {
        guard let value else { return "--" }
        return String(format: "%.*f", key.decimals, value)
    }

    private var valueColor: Color {
        if (key == .hvCurrent || key == .power), (value ?? 0) < 0 { return .cyan }
        switch key {
        case .torque, .mechanicalPower: return .orange
        default: return .primary
        }
    }
}
