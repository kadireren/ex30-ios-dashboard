import Foundation

extension Double {
    func clamped(_ limits: ClosedRange<Double>) -> Double {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

/// Android `Ex30Calculations` + ham anlık tüketim pipeline (`AndroidCarDataSource.updateInstantConsumption`).
enum Ex30Calculations {
    /// Android `Ex30Battery.USABLE_KWH_DEFAULT`.
    static let usableKwhDefault: Double = 66

    /// Android `Ex30Calculations.normalizeBatteryCapacityKwh`.
    static func normalizeBatteryCapacityKwh(_ raw: Double) -> Double {
        if raw <= 0 { return usableKwhDefault }
        if raw < 200 { return max(raw, usableKwhDefault) }
        if raw > 1_000 { return raw / 1_000 }
        return usableKwhDefault
    }

    /// Android `Ex30Calculations.normalizeBatteryEnergyKwh`.
    static func normalizeBatteryEnergyKwh(_ raw: Double, capacityKwh: Double) -> Double {
        if raw <= 0 { return 0 }
        let capacityKwhSafe = capacityKwh <= 0 ? usableKwhDefault : capacityKwh
        if raw < capacityKwhSafe * 1.2 { return raw.clamped(0...(capacityKwhSafe * 1.2)) }
        if raw > 1_000 { return (raw / 1_000).clamped(0...(capacityKwhSafe * 1.2)) }
        if raw <= 100 { return (raw / 100) * capacityKwhSafe }
        return raw.clamped(0...(capacityKwhSafe * 1.2))
    }

    /// Android `Ex30Calculations.calculateSocPercent`.
    static func calculateSocPercent(energyKwh: Double, capacityKwh: Double) -> Double {
        guard capacityKwh > 0 else { return 0 }
        return (energyKwh / capacityKwh * 100).clamped(0...100)
    }

    static func normalizePowerKw(_ raw: Double) -> Double {
        let absValue = abs(raw)
        if absValue >= 500_000 { return raw / 1_000_000 }
        if absValue >= 500 { return raw / 1_000 }
        return raw
    }

    static func isPlausiblePowerForDisplay(powerKw: Double, speedKmh: Double) -> Bool {
        guard powerKw.isFinite else { return false }
        if powerKw > 180 { return false }
        if powerKw < -130 { return false }
        if speedKmh < 8, powerKw > 70 { return false }
        if speedKmh < 8, powerKw < -70 { return false }
        return true
    }

    static func isPlausibleRawPowerKw(_ powerKw: Double) -> Bool {
        guard powerKw.isFinite else { return false }
        if powerKw > 180 { return false }
        if powerKw < -130 { return false }
        return true
    }

    static func calculateInstantKwh100Signed(signedPowerKw: Double, speedKmh: Double) -> Double? {
        if speedKmh < 3 { return nil }
        if !isPlausiblePowerForDisplay(powerKw: signedPowerKw, speedKmh: speedKmh) { return nil }
        let value = (signedPowerKw / speedKmh) * 100
        guard value.isFinite else { return nil }
        return value.clamped(-120...160)
    }

    static func formatInstantKwh100(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return String(format: "%.1f", value.clamped(-99.9...99.9))
    }

    /// VHAL gear selection kodu → Android `getGearString`.
    static func gearLabel(from raw: Double?) -> String? {
        guard let raw else { return nil }
        switch Int(raw.rounded()) {
        case 1: return "N"
        case 2: return "R"
        case 4: return "P"
        case 8: return "D"
        default: return "?"
        }
    }
}

/// Ham anlık kWh/100 km — SMOOTH/CLUSTER yok; RAW yolu.
struct RawInstantConsumptionPipeline {
    private static let speedFresh: TimeInterval = 2.5
    private static let powerFresh: TimeInterval = 2.5
    private static let nullInstantHold: TimeInterval = 4

    private(set) var displayKwh100: Double?
    private(set) var smoothKwh100: Double?
    private var smoothPipeline = SmoothInstantConsumptionPipeline()
    private var lastRawPowerKw: Double?
    private var lastPowerUpdate: Date?
    private var lastSpeedKmh: Double?
    private var lastSpeedUpdate: Date?
    private var lastValidInstantAt: Date?

    mutating func acceptPower(_ raw: Double, now: Date) {
        let normalized = Ex30Calculations.normalizePowerKw(raw)
        guard Ex30Calculations.isPlausibleRawPowerKw(normalized) else { return }
        lastRawPowerKw = normalized
        lastPowerUpdate = now
    }

    mutating func acceptSpeed(_ speedKmh: Double, now: Date) {
        guard speedKmh.isFinite else { return }
        lastSpeedKmh = speedKmh
        lastSpeedUpdate = now
    }

    mutating func update(gearLabel: String?, now: Date) {
        guard let speedKmh = lastSpeedKmh else {
            resetInstantPipelines(nil)
            return
        }

        let speedFresh = lastSpeedUpdate.map { now.timeIntervalSince($0) <= Self.speedFresh } ?? false
        let powerFresh = lastPowerUpdate.map { now.timeIntervalSince($0) <= Self.powerFresh } ?? false
        let rawPowerKw = lastRawPowerKw

        if gearLabel == "P" {
            resetInstantPipelines(0)
            return
        }
        if rawPowerKw == nil {
            resetInstantPipelines(0)
            return
        }
        if !speedFresh || !powerFresh {
            return
        }
        guard let rawPowerKw, Ex30Calculations.isPlausiblePowerForDisplay(powerKw: rawPowerKw, speedKmh: speedKmh) else {
            return
        }

        guard let rawInstant = Ex30Calculations.calculateInstantKwh100Signed(signedPowerKw: rawPowerKw, speedKmh: speedKmh) else {
            if speedKmh < 3 {
                resetInstantPipelines(0)
            } else if let lastValidInstantAt, now.timeIntervalSince(lastValidInstantAt) > Self.nullInstantHold {
                resetInstantPipelines(0)
            }
            return
        }

        lastValidInstantAt = now
        displayKwh100 = rawInstant.clamped(-99.9...99.9)
        smoothKwh100 = smoothPipeline.update(displayKwh100!, now: now)
    }

    private mutating func resetInstantPipelines(_ resetValue: Double?) {
        displayKwh100 = resetValue
        smoothPipeline.reset(resetValue)
        smoothKwh100 = resetValue
        if resetValue == nil {
            lastValidInstantAt = nil
        }
    }
}

/// Android InstantDisplayProfile.SMOOTH_DEFAULT, sampled every 250 ms.
struct SmoothInstantConsumptionPipeline {
    private var samples: [(time: Date, value: Double)] = []
    private var ema: Double?
    private var output: Double?
    private var lastUpdate: Date?
    private var pendingSign = 0
    private var pendingSignSince: Date?

    mutating func reset(_ value: Double?) {
        samples.removeAll()
        ema = value
        output = value
        lastUpdate = nil
        pendingSign = 0
        pendingSignSince = nil
    }

    mutating func update(_ raw: Double, now: Date) -> Double {
        if let lastUpdate, now.timeIntervalSince(lastUpdate) < 0.25 {
            return output ?? raw
        }
        samples.append((now, raw))
        while samples.count > 1 && now.timeIntervalSince(samples[0].time) > 4.1 {
            samples.removeFirst()
        }
        let threshold = now.addingTimeInterval(-1.1)
        while samples.count > 1 && samples[1].time <= threshold {
            samples.removeFirst()
        }
        var target = samples[0].value
        if abs(target) < 3 { target = 0 }
        let targetSign = sign(target)
        let currentSign = sign(output ?? ema ?? 0)
        if targetSign == 0 || currentSign == 0 || currentSign == targetSign {
            pendingSign = 0
            pendingSignSince = nil
        } else {
            if pendingSign != targetSign {
                pendingSign = targetSign
                pendingSignSince = now
            }
            if now.timeIntervalSince(pendingSignSince ?? now) < 0.5 { target = 0 }
        }
        let filtered = ema.map { $0 + 0.18 * (target - $0) } ?? target
        ema = filtered
        let previous = output ?? filtered
        let dt = lastUpdate.map { max(0.001, now.timeIntervalSince($0)) } ?? 0.25
        lastUpdate = now
        let delta = 42 * dt
        let limited = filtered.clamped((previous - delta)...(previous + delta)).clamped(-99.9...99.9)
        output = limited
        return limited
    }

    private func sign(_ value: Double) -> Int {
        value > 0.25 ? 1 : (value < -0.25 ? -1 : 0)
    }
}
