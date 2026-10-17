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
        // BECM 4801 ham → rawSoc; ana .soc = CrowPanel gösterge formülü (OBD), VHAL ezmez.
        precondition(OBDDecoder.decode(key: .soc, response: "6248019C40") == 80)
        precondition(OBDDecoder.decode(key: .soc, response: "6248010000") == 0)
        precondition(OBDDecoder.decode(key: .soc, response: "624801FFFF") == 131.07)
        precondition(abs(Ex30Calculations.normalizeBatteryCapacityKwh(66_000) - 66) < 0.0001)
        precondition(abs(Ex30Calculations.normalizeBatteryEnergyKwh(54_780, capacityKwh: 66) - 54.78) < 0.0001)
        precondition(abs(Ex30Calculations.calculateSocPercent(energyKwh: 54.78, capacityKwh: 66) - 83) < 0.01)
        var socResolver = TelemetryResolver()
        socResolver.put(.soc, value: 80, source: .obd, now: start)
        precondition(socResolver.value(.rawSoc, now: start) == 80)
        precondition(socResolver.value(.soc, now: start) == 81.875)
        // VHAL energy/capacity taze olsa bile OBD gösterge formülü birincil (95 ham → ~97.8).
        socResolver.put(.soc, value: 95, source: .obd, now: start)
        socResolver.put(.batteryEnergy, value: 54_780, source: .vhal, now: start)
        socResolver.put(.batteryCapacity, value: 66_000, source: .vhal, now: start)
        socResolver.put(.soc, value: 93, source: .vhal, now: start)
        socResolver.vhalConnected = true
        precondition(abs(socResolver.value(.soc, now: start)! - 97.8125) < 0.0001)
        precondition(socResolver.value(.rawSoc, now: start) == 95)
        // OBD yokken VHAL: ex30dashboard normalize(energy/capacity)×100 (bridge id 4 ezilmez).
        var vhalOnly = TelemetryResolver()
        vhalOnly.put(.batteryEnergy, value: 54_780, source: .vhal, now: start)
        vhalOnly.put(.batteryCapacity, value: 66_000, source: .vhal, now: start)
        vhalOnly.put(.soc, value: 99, source: .vhal, now: start)
        vhalOnly.vhalConnected = true
        precondition(abs(vhalOnly.value(.soc, now: start)! - 83) < 0.01)
        // Energy yoksa bridge precomputed soc son çare.
        var bridgeSocOnly = TelemetryResolver()
        bridgeSocOnly.put(.soc, value: 83, source: .vhal, now: start)
        bridgeSocOnly.vhalConnected = true
        precondition(bridgeSocOnly.value(.soc, now: start) == 83)
        socResolver.vhalConnected = false
        precondition(abs(socResolver.value(.soc, now: start)! - 97.8125) < 0.0001)
        socResolver.put(.soc, value: 0, source: .obd, now: start)
        precondition(socResolver.value(.soc, now: start) == 0)
        socResolver.put(.soc, value: 110, source: .obd, now: start)
        precondition(socResolver.value(.soc, now: start) == 100)
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
        precondition(VHALSubscription.packet(visibleSensors: [.soc, .range, .outsideTemp]) == Data([0xE3, 0x30, 1, 1, 5, 4, 5, 10, 13, 14]))
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
        precondition(DashboardSensorSelection.active(page: .main, style: .minimal, visible: [.pedal]) == [.outsideTemp, .gear])
        precondition(VHALSubscription.packet(visibleSensors: selected(.performance)) == Data([0xE3, 0x30, 1, 1, 0]))
        precondition(VHALSubscription.packet(visibleSensors: selected(.main)) == Data([0xE3, 0x30, 1, 1, 8, 1, 3, 4, 5, 6, 10, 13, 14]))
        let v168 = Ex30Calculations.calculateInstantKwh100Signed(signedPowerKw: 168, speedKmh: 50)
        precondition(v168 != nil && abs(v168! - 160) < 0.01)
        precondition(Ex30Calculations.calculateInstantKwh100Signed(signedPowerKw: 50, speedKmh: 2.9) == nil)
        precondition(Ex30Calculations.formatInstantKwh100(51.2) == "51.2")
        precondition(Ex30Calculations.formatInstantKwh100(nil) == "--")
        precondition(Ex30Calculations.gearLabel(from: 4) == "P")
        var instantPipe = RawInstantConsumptionPipeline()
        let t0 = start
        instantPipe.acceptSpeed(100, now: t0)
        instantPipe.acceptPower(50, now: t0)
        instantPipe.update(gearLabel: "D", now: t0)
        precondition(abs(instantPipe.displayKwh100! - 50) < 0.001)
        instantPipe.update(gearLabel: "P", now: t0.addingTimeInterval(1))
        precondition(instantPipe.displayKwh100 == 0)
        precondition(instantPipe.smoothKwh100 == 0)
        var smooth = SmoothInstantConsumptionPipeline()
        precondition(smooth.update(0, now: t0) == 0)
        for step in 1...4 {
            precondition(smooth.update(100, now: t0.addingTimeInterval(Double(step) * 0.25)) == 0)
        }
        precondition(smooth.update(100, now: t0.addingTimeInterval(1.25)) == 0)
        // Delayed 100 enters EMA at 1.5s; 18 is rate-limited to 10.5.
        precondition(abs(smooth.update(100, now: t0.addingTimeInterval(1.5)) - 10.5) < 0.001)
        // Extra sensor callbacks must not accelerate the 250ms filter.
        precondition(abs(smooth.update(100, now: t0.addingTimeInterval(1.6)) - 10.5) < 0.001)
        smooth.reset(0)
        precondition(smooth.update(2.9, now: t0) == 0)
        smooth.reset(nil)
        precondition(smooth.update(50, now: t0) == 50)
        for step in 1...5 {
            _ = smooth.update(-50, now: t0.addingTimeInterval(Double(step) * 0.25))
        }
        // Reversal is held at zero for 500ms before the negative target enters EMA.
        let held1 = smooth.update(-50, now: t0.addingTimeInterval(1.5))
        let held2 = smooth.update(-50, now: t0.addingTimeInterval(1.75))
        precondition(abs(held1 - 41) < 0.001)
        precondition(abs(held2 - 33.62) < 0.001)
        precondition(abs(smooth.update(-50, now: t0.addingTimeInterval(2)) - 23.12) < 0.001)
        print("Telemetry regression checks passed")
    }
}
