import Foundation

@main
enum TelemetryRegressionTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        var resolver = TelemetryResolver()
        precondition(resolver.value(.speed, now: start) == nil)
        for key in [SensorKey.soh, .odometer, .supply12v] {
            resolver.put(key, value: 42, source: .obd, now: start)
            precondition(resolver.value(key, now: start.addingTimeInterval(60)) == 42)
        }
        resolver.vhalConnected = true
        resolver.put(.speed, value: 50, source: .vhal, now: start)
        resolver.put(.speed, value: 49, source: .obd, now: start.addingTimeInterval(1))
        precondition(resolver.value(.speed, now: start.addingTimeInterval(1)) == 50)
        precondition(resolver.value(.speed, now: start.addingTimeInterval(4)) == 49)
        resolver.vhalConnected = false
        precondition(resolver.value(.speed, now: start.addingTimeInterval(2)) == 49)
        resolver.put(.range, value: 300, source: .vhal, now: start)
        precondition(resolver.value(.range, now: start.addingTimeInterval(60)) == 300)
        resolver.vhalConnected = true
        resolver.put(.speed, value: 51, source: .vhal, now: start.addingTimeInterval(5))
        precondition(resolver.value(.speed, now: start.addingTimeInterval(5)) == 51)
        resolver.put(.speed, value: .nan, source: .vhal, now: start.addingTimeInterval(6))
        precondition(resolver.value(.speed, now: start.addingTimeInterval(6)) == 51)
        resolver.put(.hvCurrent, value: -20, source: .obd, now: start)
        resolver.put(.hvVoltage, value: 400, source: .obd, now: start)
        resolver.put(.power, value: 10, source: .vhal, now: start)
        precondition(resolver.value(.power, now: start) == 10)
        precondition(resolver.value(.power, now: start.addingTimeInterval(60)) == -8)
        resolver.put(.rpm, value: 9549.3, source: .obd, now: start)
        resolver.put(.torque, value: 10, source: .obd, now: start)
        precondition(abs(resolver.value(.mechanicalPower, now: start.addingTimeInterval(60))! - 13.5962) < 0.00001)
        resolver.put(.hvCurrent, value: -10, source: .obd, now: start.addingTimeInterval(61))
        precondition(resolver.value(.power, now: start.addingTimeInterval(61)) == -4)

        precondition(OBDDecoder.decode(key: .pedal, response: "1EC02E800462E30115\r>") == 21)
        precondition(OBDDecoder.decode(key: .pedal, response: "62E30107") == 7)
        precondition(OBDDecoder.decode(key: .pedal, response: "62E30164") == 100)
        for response in ["62E301FF", "62E301", "NO DATA", "7F2231"] {
            precondition(OBDDecoder.decode(key: .pedal, response: response) == nil)
        }
        // BECM 4801 ham değeri rawSoc; ana .soc yalnızca VHAL (head unit).
        precondition(OBDDecoder.decode(key: .soc, response: "6248019C40") == 80)
        precondition(OBDDecoder.decode(key: .soc, response: "6248010000") == 0)
        precondition(OBDDecoder.decode(key: .soc, response: "624801FFFF") == 131.07)
        var socResolver = TelemetryResolver()
        socResolver.put(.soc, value: 80, source: .obd, now: start)
        precondition(socResolver.value(.rawSoc, now: start) == 80)
        precondition(socResolver.value(.soc, now: start) == nil)
        socResolver.put(.soc, value: 83, source: .vhal, now: start)
        socResolver.vhalConnected = true
        precondition(socResolver.value(.soc, now: start) == 83)
        precondition(socResolver.value(.rawSoc, now: start) == 80)
        socResolver.vhalConnected = false
        precondition(socResolver.value(.soc, now: start) == 83)
        socResolver.put(.soc, value: 0, source: .obd, now: start)
        precondition(socResolver.value(.soc, now: start) == 83)
        socResolver.put(.soc, value: 110, source: .obd, now: start)
        precondition(socResolver.value(.soc, now: start) == 83)
        let pedal = OBDDecoder.requests.filter { $0.key == .pedal }
        precondition(pedal.count == 1 && pedal[0].ecu == .vcFront && pedal[0].command == "22E301")
        func keys(_ visible: Set<SensorKey>) -> Set<SensorKey> {
            Set(OBDDecoder.enabledRequests(visibleSensors: visible).map(\.key))
        }
        precondition(keys([]).isEmpty)
        precondition(keys([.range, .gear, .nightMode]).isEmpty)
        precondition(keys([.speed]) == [.speed])
        precondition(keys([.power]) == [.hvCurrent, .hvVoltage])
        precondition(keys([.mechanicalPower]) == [.rpm, .torque])
        precondition(keys([.power, .mechanicalPower, .pedal]) == [.hvCurrent, .hvVoltage, .rpm, .torque, .pedal])
        precondition(keys([.hvVoltage]) == [.hvVoltage])
        precondition(keys([.soc, .odometer]) == [.soc, .odometer])
        precondition(keys([.rawSoc]) == [.soc])
        precondition(keys([.soc, .rawSoc]) == [.soc])
        precondition(VHALSubscription.packet(visibleSensors: []) == Data([0xE3, 0x30, 1, 1, 0]))
        precondition(VHALSubscription.packet(visibleSensors: [.speed, .power, .pedal]) == Data([0xE3, 0x30, 1, 1, 2, 1, 3]))
        precondition(VHALSubscription.packet(visibleSensors: [.soc, .range, .outsideTemp]) == Data([0xE3, 0x30, 1, 1, 3, 4, 5, 10]))
        let all = Set(SensorKey.allCases)
        func selected(_ page: DashboardPage, _ style: DashboardStyle = .minimal) -> Set<SensorKey> {
            DashboardSensorSelection.active(page: page, style: style, visible: all)
        }
        precondition(keys(selected(.main)) == [.speed, .hvCurrent, .hvVoltage, .soc, .odometer])
        for style in [DashboardStyle.sportOne, .sportTwo] {
            precondition(keys(selected(.main, style)) == [.speed, .hvCurrent, .hvVoltage, .soc, .odometer, .rpm, .torque])
        }
        precondition(keys(selected(.performance)) == [.pedal, .rpm, .torque, .motorTemp, .iemCoolantTemp])
        precondition(keys(selected(.battery)) == [.soc, .hvCurrent, .hvVoltage, .batteryTemp, .batteryTempMax, .soh, .cellMaxVoltage, .cellMinVoltage, .cellMinSoc])
        precondition(keys(selected(.technical)) == [.odometer, .supply12v, .coolingValveActual, .coolingValveRequested, .chargePowerLimit, .dischargePowerLimit])
        precondition(DashboardSensorSelection.active(page: .main, style: .minimal, visible: [.pedal]).isEmpty)
        precondition(VHALSubscription.packet(visibleSensors: selected(.performance)) == Data([0xE3, 0x30, 1, 1, 0]))
        print("Telemetry regression checks passed")
    }
}
