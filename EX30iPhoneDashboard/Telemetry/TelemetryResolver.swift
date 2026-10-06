import Foundation

/// Freshness controls source priority, never whether an existing value is displayed.
struct TelemetryResolver {
    private(set) var obd: [SensorKey: TelemetryReading] = [:]
    private(set) var vhal: [SensorKey: TelemetryReading] = [:]
    var vhalConnected = false

    mutating func put(_ key: SensorKey, value: Double, source: TelemetrySource, now: Date = Date()) {
        guard value.isFinite else { return }
        let reading = TelemetryReading(value: value, timestamp: now, source: source)
        switch source {
        case .obd: obd[key] = reading
        case .vhal: vhal[key] = reading
        }
    }

    func value(_ key: SensorKey, now: Date = Date()) -> Double? {
        // .soc yalnızca VHAL Bridge; OBD/ham (BECM 4801) asla ana göstergeye düşmesin.
        if key != .soc && key != .rawSoc,
           vhalConnected, let reading = vhal[key], reading.isFresh(maxAge: 3, now: now) {
            return reading.value
        }

        if key == .rawSoc { return obd[.soc]?.value }
        if key == .soc {
            if vhalConnected, let reading = vhal[.soc], reading.isFresh(maxAge: 3, now: now) {
                return reading.value
            }
            return vhal[.soc]?.value
        }

        // Keep OBD samples independently, including while VHAL has priority.
        // Slow samples and the inputs to derived values survive between polls.
        switch key {
        case .power:
            if let current = obd[.hvCurrent], let voltage = obd[.hvVoltage] {
                return current.value * voltage.value / 1_000
            }
        case .mechanicalPower:
            if let rpm = obd[.rpm], let torque = obd[.torque] {
                return rpm.value * torque.value / 9_549.3 * 1.35962
            }
        default: break
        }
        return obd[key]?.value ?? vhal[key]?.value
    }
}
