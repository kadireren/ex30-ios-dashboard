import Foundation

enum TelemetrySource: String {
    case obd = "OBD"
    case vhal = "VHAL"
}

struct TelemetryReading {
    let value: Double
    let timestamp: Date
    let source: TelemetrySource

    func isFresh(maxAge: TimeInterval, now: Date = Date()) -> Bool {
        now.timeIntervalSince(timestamp) <= maxAge
    }
}

enum DashboardStyle: Int, CaseIterable, Identifiable {
    case minimal
    case sportOne
    case sportTwo

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .minimal: "Minimal"
        case .sportOne: "Sport 1"
        case .sportTwo: "Sport 2"
        }
    }
}

enum DashboardAppearance: Int, CaseIterable, Identifiable {
    case system
    case day
    case night

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .system: "Sistem"
        case .day: "Gündüz"
        case .night: "Gece"
        }
    }
}

enum DashboardPage: Int, CaseIterable, Identifiable {
    case main, performance, battery, technical

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .main: "ANA"
        case .performance: "PERFORMANS"
        case .battery: "BATARYA"
        case .technical: "TEKNİK"
        }
    }
}

enum SensorKey: String, CaseIterable {
    case speed, power, soc, range, gear, currentGear, outsideTemp, nightMode
    case pedal, rpm, torque, mechanicalPower, hvCurrent, hvVoltage, odometer
    case motorTemp, iemCoolantTemp, batteryTemp, batteryTempMax, soh
    case cellMaxVoltage, cellMinVoltage, cellMinSoc, supply12v
    case coolingValveActual, coolingValveRequested, chargePowerLimit, dischargePowerLimit

    var title: String {
        switch self {
        case .speed: "Hız"
        case .power: "Batarya gücü"
        case .soc: "Batarya"
        case .range: "Kalan menzil"
        case .gear: "Vites"
        case .currentGear: "Mevcut vites"
        case .outsideTemp: "Dış sıcaklık"
        case .nightMode: "Gece modu"
        case .pedal: "Gaz pedalı PWM"
        case .rpm: "ERAD motor devri"
        case .torque: "ERAD tork"
        case .mechanicalPower: "ERAD mekanik güç"
        case .motorTemp: "ERAD motor sıcaklığı"
        case .iemCoolantTemp: "Aktarma soğutma sıcaklığı"
        case .hvCurrent: "HV akım"
        case .hvVoltage: "HV voltaj"
        case .batteryTemp: "Batarya sıcaklığı"
        case .batteryTempMax: "Maks. batarya sıcaklığı"
        case .soh: "Batarya sağlığı"
        case .cellMaxVoltage: "Maks. hücre voltajı"
        case .cellMinVoltage: "Min. hücre voltajı"
        case .cellMinSoc: "Minimum hücre SOC"
        case .odometer: "Toplam kilometre"
        case .supply12v: "12 V besleme"
        case .coolingValveActual: "HV soğutma valfi gerçek"
        case .coolingValveRequested: "HV soğutma valfi istenen"
        case .chargePowerLimit: "Şarj güç limiti"
        case .dischargePowerLimit: "Deşarj güç limiti"
        }
    }

    var unit: String {
        switch self {
        case .speed: "km/h"
        case .power, .chargePowerLimit, .dischargePowerLimit: "kW"
        case .soc, .pedal, .soh, .cellMinSoc, .coolingValveActual, .coolingValveRequested: "%"
        case .range, .odometer: "km"
        case .rpm: "rpm"
        case .torque: "Nm"
        case .mechanicalPower: "hp"
        case .motorTemp, .iemCoolantTemp, .batteryTemp, .batteryTempMax, .outsideTemp: "°C"
        case .hvCurrent: "A"
        case .hvVoltage, .cellMaxVoltage, .cellMinVoltage, .supply12v: "V"
        case .gear, .currentGear, .nightMode: ""
        }
    }

    var page: DashboardPage? {
        switch self {
        case .pedal, .rpm, .torque, .mechanicalPower, .motorTemp, .iemCoolantTemp: .performance
        case .hvCurrent, .hvVoltage, .batteryTemp, .batteryTempMax, .soh,
             .cellMaxVoltage, .cellMinVoltage, .cellMinSoc: .battery
        case .odometer, .supply12v, .coolingValveActual, .coolingValveRequested,
             .chargePowerLimit, .dischargePowerLimit, .outsideTemp: .technical
        default: nil
        }
    }

    var isUserSelectable: Bool {
        self != .nightMode && self != .gear && self != .currentGear
    }

    var decimals: Int {
        switch self {
        case .hvCurrent, .hvVoltage, .batteryTemp, .batteryTempMax, .motorTemp,
             .iemCoolantTemp, .supply12v, .chargePowerLimit, .dischargePowerLimit: 1
        case .cellMaxVoltage, .cellMinVoltage: 3
        case .soh, .cellMinSoc: 2
        default: 0
        }
    }
}
