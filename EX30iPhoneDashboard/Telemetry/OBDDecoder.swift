import Foundation

enum OBDECU: Equatable {
    case becm, vcFront, ecuE, ecuF

    var setup: [String] {
        switch self {
        case .becm: ["ATSP7", "ATSHD01635", "ATCP1D", "ATCRA1EC6AE80", "ATFCSH1DD01635", "ATFCSD300000", "ATFCSM1"]
        case .vcFront: ["ATSP7", "ATSHD01601", "ATCP1D", "ATCRA1EC02E80", "ATFCSH1DD01601", "ATFCSD300000", "ATFCSM1"]
        case .ecuE: ["ATSP7", "ATSHD01701", "ATCP1D", "ATCRA1EE02E80", "ATFCSH1DD01701", "ATFCSD300000", "ATFCSM1"]
        case .ecuF: ["ATSP7", "ATSHD01637", "ATCP1D", "ATCRA1EC6EE80", "ATFCSH1DD01637", "ATFCSD300000", "ATFCSM1"]
        }
    }
}

struct OBDRequest {
    let key: SensorKey
    let ecu: OBDECU
    let command: String
    let interval: TimeInterval

    var priority: Int {
        if interval <= 0.1 { return 0 }
        if interval <= 1 { return 1 }
        if interval < 10 { return 2 }
        return 3
    }
}

enum OBDDecoder {
    static func enabledRequests(visibleSensors: Set<SensorKey>) -> [OBDRequest] {
        var required = visibleSensors
        if required.contains(.rawSoc) { required.insert(.soc) }
        if required.contains(.power) { required.formUnion([.hvCurrent, .hvVoltage]) }
        if required.contains(.mechanicalPower) { required.formUnion([.rpm, .torque]) }
        return requests.filter { required.contains($0.key) }
    }

    static let requests: [OBDRequest] = [
        .init(key: .pedal, ecu: .vcFront, command: "22E301", interval: 0.10),
        .init(key: .speed, ecu: .ecuE, command: "22F40D", interval: 0.10),
        .init(key: .hvCurrent, ecu: .becm, command: "224802", interval: 0.10),
        .init(key: .hvVoltage, ecu: .becm, command: "224803", interval: 0.50),
        .init(key: .soc, ecu: .becm, command: "224801", interval: 1.00),
        .init(key: .rpm, ecu: .ecuF, command: "22E303", interval: 0.10),
        .init(key: .torque, ecu: .ecuF, command: "22E304", interval: 0.10),
        .init(key: .motorTemp, ecu: .ecuF, command: "22E306", interval: 2.0),
        .init(key: .iemCoolantTemp, ecu: .ecuF, command: "22EE9A", interval: 5.0),
        .init(key: .batteryTemp, ecu: .becm, command: "22491B", interval: 5.0),
        .init(key: .batteryTempMax, ecu: .becm, command: "224945", interval: 5.0),
        .init(key: .soh, ecu: .becm, command: "22496D", interval: 10.0),
        .init(key: .cellMaxVoltage, ecu: .becm, command: "224907", interval: 5.0),
        .init(key: .cellMinVoltage, ecu: .becm, command: "224908", interval: 5.0),
        .init(key: .cellMinSoc, ecu: .becm, command: "22487A", interval: 5.0),
        .init(key: .odometer, ecu: .becm, command: "22DD01", interval: 10.0),
        .init(key: .supply12v, ecu: .becm, command: "ATRV", interval: 10.0),
        .init(key: .coolingValveActual, ecu: .vcFront, command: "22E34A", interval: 5.0),
        .init(key: .coolingValveRequested, ecu: .vcFront, command: "22E349", interval: 5.0),
        .init(key: .chargePowerLimit, ecu: .becm, command: "22489C", interval: 2.0),
        .init(key: .dischargePowerLimit, ecu: .becm, command: "22489E", interval: 2.0)
    ]

    static func decode(key: SensorKey, response: String) -> Double? {
        if key == .supply12v {
            let normalized = response.uppercased().replacingOccurrences(of: "\r", with: " ")
            return normalized.split(separator: " ").compactMap { token -> Double? in
                guard token.hasSuffix("V") else { return nil }
                return Double(token.dropLast())
            }.first
        }
        let did: String
        switch key {
        case .pedal: did = "E301"
        case .speed: did = "F40D"
        case .hvCurrent: did = "4802"
        case .hvVoltage: did = "4803"
        case .soc: did = "4801"
        case .rpm: did = "E303"
        case .torque: did = "E304"
        case .odometer: did = "DD01"
        case .motorTemp: did = "E306"
        case .iemCoolantTemp: did = "EE9A"
        case .batteryTemp: did = "491B"
        case .batteryTempMax: did = "4945"
        case .soh: did = "496D"
        case .cellMaxVoltage: did = "4907"
        case .cellMinVoltage: did = "4908"
        case .cellMinSoc: did = "487A"
        case .coolingValveActual: did = "E34A"
        case .coolingValveRequested: did = "E349"
        case .chargePowerLimit: did = "489C"
        case .dischargePowerLimit: did = "489E"
        default: return nil
        }
        let cleaned = response.uppercased().filter(\.isHexDigit)
        guard let range = cleaned.range(of: "62" + did), range.upperBound < cleaned.endIndex else { return nil }
        let payload = String(cleaned[range.upperBound...])
        func hex(_ count: Int, offset: Int = 0) -> Int? {
            guard payload.count >= offset + count else { return nil }
            let start = payload.index(payload.startIndex, offsetBy: offset)
            let end = payload.index(start, offsetBy: count)
            return Int(payload[start..<end], radix: 16)
        }
        switch key {
        case .pedal:
            // Confirmed Sensor Lab PWM scale: released pedal is about 7, not 0.
            guard let raw = hex(2), raw <= 100 else { return nil }
            return Double(raw)
        case .speed: return hex(2).map(Double.init)
        case .hvCurrent: return hex(4).map { (Double($0) - 16_384) * 0.1 }
        case .hvVoltage: return hex(4).map { Double($0) / 100 }
        case .soc: return hex(4).map { Double($0) / 500 }
        case .rpm: return hex(4).map { Double($0 - 16_384) }
        case .torque: return hex(4).map { Double($0 - 8_188) }
        case .odometer: return hex(6).map(Double.init)
        case .motorTemp: return hex(2).map { Double($0) - 50 }
        case .iemCoolantTemp: return hex(2).map { Double($0) - 40 }
        case .batteryTemp: return hex(4).map { Double($0) / 100 - 50 }
        case .batteryTempMax: return hex(4, offset: 2).map { Double($0) / 100 - 50 }
        case .soh: return hex(8).map { Double($0) * 0.01 }
        case .cellMaxVoltage, .cellMinVoltage: return hex(4, offset: 2).map { Double($0) / 1_000 }
        case .cellMinSoc: return hex(8).map { Double($0) / 1_000_000 }
        case .coolingValveActual, .coolingValveRequested: return hex(2).map(Double.init)
        case .chargePowerLimit, .dischargePowerLimit: return hex(8).map { Double($0) / 1_000_000 }
        default: return nil
        }
    }
}
