import Foundation
import UIKit

@MainActor
final class TelemetryStore: ObservableObject {
    private static let sleepAfterVhalDisconnectKey = "sleepAfterVhalDisconnect"
    private static let demoModeKey = "demoMode"
    private static let sleepAfterVhalDisconnectDelay: TimeInterval = 4 * 60

    @Published private(set) var obdConnected = false
    @Published private(set) var vhalConnected = false
    @Published private(set) var obdStatus = "OBD hazırlanıyor"
    @Published private(set) var vhalStatus = "VHAL hazırlanıyor"
    @Published var style: DashboardStyle {
        didSet {
            UserDefaults.standard.set(style.rawValue, forKey: "dashboardStyle")
            updateSensorSelection()
        }
    }
    @Published var appearance: DashboardAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "dashboardAppearance") }
    }
    /// VHAL koptuktan 4 dk sonra ekranın uykuya geçmesine izin ver. Varsayılan: açık.
    @Published var sleepAfterVhalDisconnect: Bool {
        didSet {
            UserDefaults.standard.set(sleepAfterVhalDisconnect, forKey: Self.sleepAfterVhalDisconnectKey)
            updateIdleTimerPolicy()
        }
    }
    /// Canlı OBD/VHAL olmadan UI önizlemesi için kurgusal sensör değerleri.
    @Published var demoMode: Bool {
        didSet { UserDefaults.standard.set(demoMode, forKey: Self.demoModeKey) }
    }
    @Published private(set) var resolver = TelemetryResolver()
    /// Android `instantKwhPer100KmRaw` (±99.9, P viteste 0).
    @Published private(set) var rawInstantKwhPer100Km: Double?
    @Published var visibleSensors: Set<SensorKey> {
        didSet {
            UserDefaults.standard.set(visibleSensors.map(\.rawValue), forKey: "visibleSensors")
            updateSensorSelection()
        }
    }

    /// Demo açıksa kurgusal anlık tüketim; aksi halde gerçek pipeline.
    var displayInstantKwhPer100Km: Double? {
        demoMode ? DemoTelemetry.instantKwhPer100Km() : rawInstantKwhPer100Km
    }

    private var obd: OBDCentral?
    private var vhal: VHALPeripheral?
    private var started = false
    private var freshnessTimer: Timer?
    private var sleepAfterDisconnectTimer: Timer?
    private var activePage: DashboardPage = .main
    private var lastKnownValues: [SensorKey: Double] = [:]
    private var rawInstantPipeline = RawInstantConsumptionPipeline()

    func setActivePage(_ page: DashboardPage) {
        activePage = page
        updateSensorSelection()
    }

    private func updateSensorSelection() {
        let active = DashboardSensorSelection.active(page: activePage, style: style, visible: visibleSensors)
        obd?.setVisibleSensors(active)
        vhal?.setVisibleSensors(active)
    }

    init() {
        style = DashboardStyle(rawValue: UserDefaults.standard.integer(forKey: "dashboardStyle")) ?? .minimal
        appearance = DashboardAppearance(rawValue: UserDefaults.standard.integer(forKey: "dashboardAppearance")) ?? .system
        demoMode = UserDefaults.standard.bool(forKey: Self.demoModeKey)
        if UserDefaults.standard.object(forKey: Self.sleepAfterVhalDisconnectKey) == nil {
            sleepAfterVhalDisconnect = true
            UserDefaults.standard.set(true, forKey: Self.sleepAfterVhalDisconnectKey)
        } else {
            sleepAfterVhalDisconnect = UserDefaults.standard.bool(forKey: Self.sleepAfterVhalDisconnectKey)
        }
        if let saved = UserDefaults.standard.stringArray(forKey: "visibleSensors") {
            var restored = Set(saved.compactMap(SensorKey.init(rawValue:)))
            if UserDefaults.standard.integer(forKey: "visibleSensorsVersion") < 1 {
                restored.formUnion(SensorKey.allCases.filter(\.isUserSelectable))
                UserDefaults.standard.set(1, forKey: "visibleSensorsVersion")
            }
            if UserDefaults.standard.integer(forKey: "visibleSensorsVersion") < 2 {
                restored.insert(.rawSoc)
                UserDefaults.standard.set(2, forKey: "visibleSensorsVersion")
            }
            visibleSensors = restored
        } else {
            visibleSensors = Set(SensorKey.allCases.filter(\.isUserSelectable))
            UserDefaults.standard.set(2, forKey: "visibleSensorsVersion")
        }
    }

    func setVisible(_ key: SensorKey, _ visible: Bool) {
        if visible { visibleSensors.insert(key) } else { visibleSensors.remove(key) }
    }

    func start() {
        guard !started else { return }
        started = true
        // Re-evaluate source selection even when VHAL silently stops sending.
        freshnessTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncRawInstantConsumption()
                self?.objectWillChange.send()
            }
        }
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
                    self?.resolver.vhalConnected = connected
                    self?.vhalConnected = connected
                    self?.vhalStatus = message
                    self?.updateIdleTimerPolicy()
                }
            })
        updateSensorSelection()
        obd?.start()
        vhal?.start()
        updateIdleTimerPolicy()
    }

    func stop() {
        freshnessTimer?.invalidate()
        freshnessTimer = nil
        sleepAfterDisconnectTimer?.invalidate()
        sleepAfterDisconnectTimer = nil
        resolver.vhalConnected = false
        obd?.stop()
        vhal?.stop()
        obd = nil
        vhal = nil
        obdConnected = false
        vhalConnected = false
        obdStatus = "OBD durduruldu"
        vhalStatus = "VHAL durduruldu"
        started = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// VHAL bağlıyken veya özellik kapalıyken ekranı uyanık tut;
    /// özellik açıkken bağlantı koptuktan 4 dk sonra uykuya izin ver.
    private func updateIdleTimerPolicy() {
        sleepAfterDisconnectTimer?.invalidate()
        sleepAfterDisconnectTimer = nil
        guard started else {
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }
        if vhalConnected || !sleepAfterVhalDisconnect {
            UIApplication.shared.isIdleTimerDisabled = true
            return
        }
        UIApplication.shared.isIdleTimerDisabled = true
        sleepAfterDisconnectTimer = Timer.scheduledTimer(
            withTimeInterval: Self.sleepAfterVhalDisconnectDelay,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.started, !self.vhalConnected, self.sleepAfterVhalDisconnect else { return }
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    func value(_ key: SensorKey) -> Double? {
        if demoMode { return DemoTelemetry.value(for: key) }
        return resolver.value(key) ?? lastKnownValues[key]
    }

    private func put(_ key: SensorKey, value: Double, source: TelemetrySource, now: Date = Date()) {
        resolver.put(key, value: value, source: source, now: now)

        // Never blank a sensor between its scheduled polls. Cache every value the
        // resolver can currently produce, including derived power values.
        for sensor in SensorKey.allCases {
            if let resolved = resolver.value(sensor) {
                lastKnownValues[sensor] = resolved
            }
        }
        feedRawInstantInputs(changed: key, now: now)
        syncRawInstantConsumption(now: now)
    }

    private func feedRawInstantInputs(changed key: SensorKey, now: Date) {
        guard !demoMode else { return }
        let live: (SensorKey) -> Double? = { resolver.value($0) ?? lastKnownValues[$0] }
        switch key {
        case .speed:
            if let speed = live(.speed) { rawInstantPipeline.acceptSpeed(speed, now: now) }
        case .power:
            if let power = live(.power) { rawInstantPipeline.acceptPower(power, now: now) }
        case .hvCurrent, .hvVoltage:
            if live(.power) != nil, let power = live(.power) {
                rawInstantPipeline.acceptPower(power, now: now)
            }
        default:
            break
        }
    }

    private func syncRawInstantConsumption(now: Date = Date()) {
        // Demo açıkken canlı gear/power ile pipeline'ı kirletme; gerçek bağlantı korunur.
        guard !demoMode else { return }
        let gear = Ex30Calculations.gearLabel(from: resolver.value(.gear) ?? lastKnownValues[.gear])
        rawInstantPipeline.update(gearLabel: gear, now: now)
        rawInstantKwhPer100Km = rawInstantPipeline.displayKwh100
    }
}

/// Canlı bağlantı olmadan ana/alt sayfa önizlemesi için makul kurgusal okumalar.
enum DemoTelemetry {
    static func instantKwhPer100Km(now: Date = Date()) -> Double {
        let wave = sin(now.timeIntervalSinceReferenceDate / 3.2)
        return (16 + 14 * wave).clamped(-99.9...99.9)
    }

    static func value(for key: SensorKey, now: Date = Date()) -> Double? {
        let mid = sin(now.timeIntervalSinceReferenceDate / 3.2)
        switch key {
        case .speed: return (78 + 16 * mid).clamped(0...180)
        case .power: return (18 + 22 * mid).clamped(-99.9...99.9)
        case .soc: return 72
        case .rawSoc: return 70.4
        case .range: return 268
        case .odometer: return 12_450
        case .torque: return (160 + 70 * mid).clamped(-400...400)
        case .mechanicalPower: return (95 + 40 * mid).clamped(-200...270)
        case .outsideTemp: return 18
        case .pedal: return (28 + 22 * mid).clamped(0...100)
        case .rpm: return (5_800 + 1_200 * mid).clamped(0...12_000)
        case .hvCurrent: return (-38 + 20 * mid).clamped(-400...400)
        case .hvVoltage: return 398
        case .motorTemp: return 41
        case .iemCoolantTemp: return 36
        case .batteryTemp: return 24
        case .batteryTempMax: return 27
        case .soh: return 97.5
        case .cellMaxVoltage: return 4.118
        case .cellMinVoltage: return 4.052
        case .cellMinSoc: return 68.2
        case .supply12v: return 13.8
        case .coolingValveActual: return 40
        case .coolingValveRequested: return 42
        case .chargePowerLimit: return 150
        case .dischargePowerLimit: return 220
        case .gear: return 4
        case .currentGear: return 4
        case .nightMode: return 0
        case .batteryEnergy: return 47.5
        case .batteryCapacity: return 66
        }
    }
}
