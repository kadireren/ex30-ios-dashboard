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
        if vhalConnected, let reading = vhal[key], reading.isFresh(maxAge: 3, now: now) {
            return reading.value
        }

        if key == .rawSoc { return obd[.soc]?.value }
        if key == .soc {
            // Ana gösterge = araç head unit (VHAL). OBD 4801 formülü yalnızca rawSoc/batarya detayında.
            // VHAL gelene kadar nil → "--"; kopunca son head-unit değeri (range gibi), OBD'ye düşülmez.
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
