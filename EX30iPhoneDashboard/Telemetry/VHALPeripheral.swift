@preconcurrency import CoreBluetooth
import Foundation

final class VHALPeripheral: NSObject, CBPeripheralManagerDelegate, @unchecked Sendable {
    static let serviceUUID = CBUUID(string: "7D2F0001-8D3B-4A6C-9F21-6A9B4E303001")
    static let telemetryUUID = CBUUID(string: "7D2F0002-8D3B-4A6C-9F21-6A9B4E303001")
    static let subscriptionUUID = CBUUID(string: "7D2F0003-8D3B-4A6C-9F21-6A9B4E303001")

    private let queue = DispatchQueue(label: "com.kadireren.ex30dashboard.vhal")
    private var manager: CBPeripheralManager!
    private var subscriptionCharacteristic: CBMutableCharacteristic?
    private var isConfigured = false
    private var lastSequence: UInt32?
    private var subscriptionPacket = VHALSubscription.packet(visibleSensors: [])
    private let onValues: ([SensorKey: Double]) -> Void
    private let onState: (Bool, String) -> Void

    init(onValues: @escaping ([SensorKey: Double]) -> Void,
         onState: @escaping (Bool, String) -> Void) {
        self.onValues = onValues
        self.onState = onState
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: queue)
    }

    func start() {
        queue.async { [weak self] in self?.configureIfReady() }
    }

    func setVisibleSensors(_ sensors: Set<SensorKey>) {
        queue.async { [weak self] in
            guard let self else { return }
            subscriptionPacket = VHALSubscription.packet(visibleSensors: sensors)
            publishSubscription()
        }
    }

    private func publishSubscription() {
        guard manager.state == .poweredOn, let subscriptionCharacteristic,
              !(subscriptionCharacteristic.subscribedCentrals ?? []).isEmpty else { return }
        // When the transmit queue is full, CoreBluetooth calls the ready delegate below.
        manager.updateValue(subscriptionPacket, for: subscriptionCharacteristic, onSubscribedCentrals: nil)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        publishSubscription()
    }

    func stop() {
        queue.async { [weak self] in
            self?.manager.stopAdvertising()
            self?.manager.removeAllServices()
            self?.isConfigured = false
            self?.onState(false, "VHAL durduruldu")
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        configureIfReady()
    }

    private func configureIfReady() {
        guard manager.state == .poweredOn else {
            isConfigured = false
            onState(false, manager.state == .poweredOff ? "Bluetooth kapalı" : "VHAL BLE bekleniyor")
            return
        }
        guard !isConfigured else { return }
        isConfigured = true
        manager.stopAdvertising()
        manager.removeAllServices()

        let telemetry = CBMutableCharacteristic(type: Self.telemetryUUID,
                                                 properties: [.write, .writeWithoutResponse],
                                                 value: nil,
                                                 permissions: [.writeable])
        let subscription = CBMutableCharacteristic(type: Self.subscriptionUUID,
                                                    properties: [.read, .notify],
                                                    value: nil,
                                                    permissions: [.readable])
        subscriptionCharacteristic = subscription
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [telemetry, subscription]
        manager.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            isConfigured = false
            onState(false, "VHAL servisi açılamadı")
            return
        }
        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey: "EX30 iPhone Dashboard",
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]
        ])
        onState(false, "VHAL Bridge bekleniyor")
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil { onState(false, "VHAL yayını başlatılamadı") }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        lastSequence = nil
        onState(true, "VHAL bağlı")
        publishSubscription()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        onState(false, "VHAL bağlantısı kesildi")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == Self.subscriptionUUID else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
            return
        }
        guard request.offset <= subscriptionPacket.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = subscriptionPacket.subdata(in: request.offset..<subscriptionPacket.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for request in requests where request.characteristic.uuid == Self.telemetryUUID {
            if let value = request.value { consume(value) }
            if request.characteristic.properties.contains(.write) {
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }

    private func consume(_ data: Data) {
        guard data.count >= 4, data[0] == 0xE3, data[1] == 0x30, data[2] == 1 else { return }
        if data[3] == 2 { consumeTelemetry(data) }
    }

    private func consumeTelemetry(_ data: Data) {
        guard data.count >= 13 else { return }
        let sequence = data.uint32LE(at: 4)
        if let lastSequence, sequence <= lastSequence { return }
        lastSequence = sequence
        let count = Int(data[12])
        guard data.count >= 13 + count * 5 else { return }
        var values: [SensorKey: Double] = [:]
        for index in 0..<count {
            let offset = 13 + index * 5
            guard let key = Self.sensorIDToKey[data[offset]] else { continue }
            values[key] = Double(data.float32LE(at: offset + 1))
        }
        if !values.isEmpty { onValues(values) }
    }

    private static let sensorIDToKey: [UInt8: SensorKey] = [
        1: .speed, 2: .speed, 3: .power, 4: .soc, 5: .range,
        6: .gear, 7: .currentGear, 10: .outsideTemp, 11: .nightMode
    ]

}

private extension Data {
    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset]) |
        (UInt32(self[offset + 1]) << 8) |
        (UInt32(self[offset + 2]) << 16) |
        (UInt32(self[offset + 3]) << 24)
    }

    func float32LE(at offset: Int) -> Float {
        Float(bitPattern: uint32LE(at: offset))
    }
}
