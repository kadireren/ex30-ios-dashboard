@preconcurrency import CoreBluetooth
import Foundation

final class OBDCentral: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    private static let serviceUUID = CBUUID(string: "18F0")
    private static let notifyUUID = CBUUID(string: "2AF0")
    private static let writeUUID = CBUUID(string: "2AF1")

    private let queue = DispatchQueue(label: "com.kadireren.ex30dashboard.obd")
    private var manager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var notifyCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    private var receiveBuffer = ""
    private var pendingCompletion: ((String?) -> Void)?
    private var timeoutWork: DispatchWorkItem?
    private var pollTimer: DispatchSourceTimer?
    private var currentECU: OBDECU?
    private var nextDue: [SensorKey: Date] = [:]
    private var enabledRequests: [OBDRequest] = []
    private var reconnectWork: DispatchWorkItem?

    private let onValue: (SensorKey, Double) -> Void
    private let onState: (Bool, String) -> Void

    init(onValue: @escaping (SensorKey, Double) -> Void,
         onState: @escaping (Bool, String) -> Void) {
        self.onValue = onValue
        self.onState = onState
        super.init()
        manager = CBCentralManager(delegate: self, queue: queue)
    }

    func start() { queue.async { [weak self] in self?.scanIfReady() } }

    func setVisibleSensors(_ sensors: Set<SensorKey>) {
        queue.async { [weak self] in
            guard let self else { return }
            enabledRequests = OBDDecoder.enabledRequests(visibleSensors: sensors)
            let enabled = Set(enabledRequests.map(\.key))
            nextDue = nextDue.filter { enabled.contains($0.key) }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            reconnectWork?.cancel()
            pollTimer?.cancel()
            pollTimer = nil
            manager.stopScan()
            if let peripheral { manager.cancelPeripheralConnection(peripheral) }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { scanIfReady() }
        else { onState(false, central.state == .poweredOff ? "Bluetooth kapalı" : "OBD BLE bekleniyor") }
    }

    private func scanIfReady() {
        guard manager.state == .poweredOn, peripheral == nil else { return }
        onState(false, "IOS-Vlink aranıyor")
        manager.scanForPeripherals(withServices: [Self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        onState(false, "OBD bağlanıyor")
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onState(false, "OBD servisi okunuyor")
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        disconnected("OBD bağlantısı kurulamadı")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
        disconnected("OBD bağlantısı kesildi")
    }

    private func disconnected(_ message: String) {
        pollTimer?.cancel()
        pollTimer = nil
        pendingCompletion?(nil)
        pendingCompletion = nil
        peripheral = nil
        notifyCharacteristic = nil
        writeCharacteristic = nil
        currentECU = nil
        onState(false, message + " · yeniden deneniyor")
        reconnectWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scanIfReady() }
        reconnectWork = work
        queue.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            disconnected("OBD servisi bulunamadı")
            return
        }
        peripheral.discoverCharacteristics([Self.notifyUUID, Self.writeUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        notifyCharacteristic = service.characteristics?.first(where: { $0.uuid == Self.notifyUUID })
        writeCharacteristic = service.characteristics?.first(where: { $0.uuid == Self.writeUUID })
        guard let notifyCharacteristic, writeCharacteristic != nil else {
            disconnected("OBD veri kanalı bulunamadı")
            return
        }
        peripheral.setNotifyValue(true, for: notifyCharacteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, characteristic.isNotifying else {
            disconnected("OBD bildirim kanalı açılamadı")
            return
        }
        initializeELM()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value,
              let text = String(data: data, encoding: .utf8) else { return }
        receiveBuffer += text
        guard receiveBuffer.contains(">") else { return }
        timeoutWork?.cancel()
        let response = receiveBuffer
        receiveBuffer = ""
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(response)
    }

    private func initializeELM() {
        let commands = ["ATZ", "ATE0", "ATE0", "ATL0", "ATS0", "ATH1", "ATM0", "ATAT1"]
        run(commands: commands, index: 0) { [weak self] success in
            guard let self else { return }
            if success {
                onState(true, "OBD bağlı")
                startPolling()
            } else {
                if let peripheral { manager.cancelPeripheralConnection(peripheral) }
            }
        }
    }

    private func run(commands: [String], index: Int,
                     shouldContinue: @escaping () -> Bool = { true },
                     completion: @escaping (Bool) -> Void) {
        guard shouldContinue() else { completion(false); return }
        guard index < commands.count else { completion(true); return }
        send(commands[index], timeout: commands[index] == "ATZ" ? 4 : 2.5) { [weak self] response in
            guard let self, let response, !response.uppercased().contains("ERROR") else {
                completion(false)
                return
            }
            run(commands: commands, index: index + 1, shouldContinue: shouldContinue, completion: completion)
        }
    }

    private func send(_ command: String, timeout: TimeInterval = 2.5,
                      completion: @escaping (String?) -> Void) {
        guard pendingCompletion == nil, let peripheral, let writeCharacteristic else {
            completion(nil)
            return
        }
        receiveBuffer = ""
        pendingCompletion = completion
        let data = Data((command + "\r").utf8)
        let type: CBCharacteristicWriteType = writeCharacteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: writeCharacteristic, type: type)
        let work = DispatchWorkItem { [weak self] in
            guard let self, pendingCompletion != nil else { return }
            pendingCompletion = nil
            receiveBuffer = ""
            completion(nil)
        }
        timeoutWork = work
        queue.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    private func startPolling() {
        nextDue.removeAll()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20))
        timer.setEventHandler { [weak self] in self?.pollNext() }
        pollTimer = timer
        timer.resume()
    }

    private func pollNext() {
        guard pendingCompletion == nil else { return }
        let now = Date()
        guard let request = enabledRequests
            .filter({ now >= nextDue[$0.key, default: .distantPast] })
            .sorted(by: {
                let leftDue = nextDue[$0.key, default: .distantPast]
                let rightDue = nextDue[$1.key, default: .distantPast]
                if leftDue != rightDue { return leftDue < rightDue }
                if $0.priority != $1.priority { return $0.priority < $1.priority }
                if ($0.ecu == currentECU) != ($1.ecu == currentECU) { return $0.ecu == currentECU }
                return $0.interval < $1.interval
            })
            .first else { return }

        let query: () -> Void = { [weak self] in
            guard let self else { return }
            guard enabledRequests.contains(where: { $0.key == request.key }) else { return }
            send(request.command) { [weak self] response in
                guard let self else { return }
                let value = response.flatMap { OBDDecoder.decode(key: request.key, response: $0) }
                if let value { onValue(request.key, value) }
                nextDue[request.key] = Date().addingTimeInterval(value == nil ? 1 : request.interval)
            }
        }
        guard currentECU != request.ecu else { query(); return }
        // A partial setup must never leave the previous ECU marked as configured.
        currentECU = nil
        run(commands: request.ecu.setup, index: 0, shouldContinue: { [weak self] in
            self?.enabledRequests.contains(where: { $0.key == request.key }) ?? false
        }) { [weak self] success in
            guard let self else { return }
            if success { currentECU = request.ecu; query() }
            else { nextDue[request.key] = Date().addingTimeInterval(1) }
        }
    }
}
