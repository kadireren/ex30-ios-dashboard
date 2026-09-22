import Foundation

@MainActor
final class TelemetryStore: ObservableObject {
    @Published private(set) var obdConnected = false
    @Published private(set) var vhalConnected = false
    @Published private(set) var obdStatus = "OBD hazırlanıyor"
    @Published private(set) var vhalStatus = "VHAL hazırlanıyor"
    @Published var style: DashboardStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "dashboardStyle") }
    }
    @Published var appearance: DashboardAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "dashboardAppearance") }
    }
    @Published private(set) var readings: [SensorKey: TelemetryReading] = [:]
    @Published var visibleSensors: Set<SensorKey> {
        didSet { UserDefaults.standard.set(visibleSensors.map(\.rawValue), forKey: "visibleSensors") }
    }

    private var obd: OBDCentral?
    private var vhal: VHALPeripheral?
    private var started = false

    init() {
        style = DashboardStyle(rawValue: UserDefaults.standard.integer(forKey: "dashboardStyle")) ?? .minimal
        appearance = DashboardAppearance(rawValue: UserDefaults.standard.integer(forKey: "dashboardAppearance")) ?? .system
        if let saved = UserDefaults.standard.stringArray(forKey: "visibleSensors") {
            var restored = Set(saved.compactMap(SensorKey.init(rawValue:)))
            if UserDefaults.standard.integer(forKey: "visibleSensorsVersion") < 1 {
                restored.formUnion(SensorKey.allCases.filter(\.isUserSelectable))
                UserDefaults.standard.set(1, forKey: "visibleSensorsVersion")
            }
            visibleSensors = restored
        } else {
            visibleSensors = Set(SensorKey.allCases.filter(\.isUserSelectable))
            UserDefaults.standard.set(1, forKey: "visibleSensorsVersion")
        }
    }

    func setVisible(_ key: SensorKey, _ visible: Bool) {
        if visible { visibleSensors.insert(key) } else { visibleSensors.remove(key) }
    }

    func start() {
        guard !started else { return }
        started = true
        obd = OBDCentral(
            onValue: { [weak self] key, value in
                Task { @MainActor in self?.put(key, value: value, source: .obd) }
            },
            onState: { [weak self] connected, message in
                Task { @MainActor in
                    self?.obdConnected = connected
                    self?.obdStatus = message
                }
            })
        vhal = VHALPeripheral(
            onValues: { [weak self] values in
                Task { @MainActor in values.forEach { self?.put($0.key, value: $0.value, source: .vhal) } }
            },
            onState: { [weak self] connected, message in
                Task { @MainActor in
                    self?.vhalConnected = connected
                    self?.vhalStatus = message
                }
            })
        obd?.start()
        vhal?.start()
    }

    func stop() {
        obd?.stop()
        vhal?.stop()
        started = false
    }

    func value(_ key: SensorKey) -> Double? {
        switch key {
        case .power:
            if let vhal = fresh(.power, source: .vhal) { return vhal.value }
            guard let current = fresh(.hvCurrent, source: .obd),
                  let voltage = fresh(.hvVoltage, source: .obd) else { return nil }
            return current.value * voltage.value / 1_000
        case .mechanicalPower:
            guard let rpm = fresh(.rpm, source: .obd), let torque = fresh(.torque, source: .obd) else { return nil }
            return rpm.value * torque.value / 9_549.3 * 1.35962
        case .speed, .soc, .range:
            return fresh(key, source: .vhal)?.value ?? fresh(key, source: .obd)?.value
        default:
            return fresh(key, source: .vhal)?.value ?? fresh(key, source: .obd)?.value
        }
    }

    private func fresh(_ key: SensorKey, source: TelemetrySource) -> TelemetryReading? {
        guard let reading = readings[key], reading.source == source,
              reading.isFresh(maxAge: source == .vhal ? 3 : 5) else { return nil }
        return reading
    }

    private func put(_ key: SensorKey, value: Double, source: TelemetrySource) {
        if source == .vhal || readings[key]?.source != .vhal || !(readings[key]?.isFresh(maxAge: 3) ?? false) {
            readings[key] = TelemetryReading(value: value, timestamp: Date(), source: source)
        }
        if key == .hvCurrent || key == .hvVoltage || key == .rpm || key == .torque {
            objectWillChange.send()
        }
    }
}
