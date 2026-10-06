import Foundation
import UIKit

@MainActor
final class TelemetryStore: ObservableObject {
    private static let sleepAfterVhalDisconnectKey = "sleepAfterVhalDisconnect"
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
    @Published private(set) var resolver = TelemetryResolver()
    @Published var visibleSensors: Set<SensorKey> {
        didSet {
            UserDefaults.standard.set(visibleSensors.map(\.rawValue), forKey: "visibleSensors")
            updateSensorSelection()
        }
    }

    private var obd: OBDCentral?
    private var vhal: VHALPeripheral?
    private var started = false
    private var freshnessTimer: Timer?
    private var sleepAfterDisconnectTimer: Timer?
    private var activePage: DashboardPage = .main
    private var lastKnownValues: [SensorKey: Double] = [:]

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
            Task { @MainActor in self?.objectWillChange.send() }
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
        resolver.value(key) ?? lastKnownValues[key]
    }

    private func put(_ key: SensorKey, value: Double, source: TelemetrySource) {
        resolver.put(key, value: value, source: source)

        // Never blank a sensor between its scheduled polls. Cache every value the
        // resolver can currently produce, including derived power values.
        for sensor in SensorKey.allCases {
            if let resolved = resolver.value(sensor) {
                lastKnownValues[sensor] = resolved
            }
        }
    }
}
