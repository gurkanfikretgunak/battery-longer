import Foundation
import IOKit
import IOKit.ps

/// Reads the internal battery through IOKit and publishes snapshots.
///
/// Two signals feed `onChange`:
///  1. `IOPSNotificationCreateRunLoopSource` – fires whenever the power source changes.
///  2. A safety-net timer (`Policy.pollInterval`) so a missed notification can never
///     stall the enforcement timeline.
///
/// Set `BLS_SIMULATE="<level>,<ac|battery>"` in the environment to fake a reading
/// (used for manual testing of the warning → enforcement flow).
final class BatteryMonitor {
    var onChange: ((BatterySnapshot) -> Void)?

    private(set) var latest: BatterySnapshot = .unknown
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?

    func start() {
        publish()

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.publish()
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        timer = Timer.scheduledTimer(withTimeInterval: Policy.pollInterval, repeats: true) { [weak self] _ in
            self?.publish()
        }
        timer?.tolerance = 1
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    /// Forces a fresh read and notifies listeners.
    func publish() {
        let snapshot = Self.read() ?? latest
        latest = snapshot
        onChange?(snapshot)
    }

    // MARK: - Reading

    static func hasInternalBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else { continue }
            if info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType { return true }
        }
        return false
    }

    static func read() -> BatterySnapshot? {
        if let simulated = readSimulated() { return simulated }

        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }

            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let level = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current

            let state = info[kIOPSPowerSourceStateKey] as? String
            let pluggedIn = state == kIOPSACPowerValue
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let charged = info[kIOPSIsChargedKey] as? Bool ?? false

            func minutes(_ key: String) -> Int? {
                guard let value = info[key] as? Int, value >= 0 else { return nil }
                return value
            }

            let health = readSmartBattery()

            return BatterySnapshot(
                level: min(100, Swift.max(0, level)),
                isPluggedIn: pluggedIn,
                isCharging: charging,
                isCharged: charged,
                minutesToEmpty: pluggedIn ? nil : minutes(kIOPSTimeToEmptyKey),
                minutesToFull: pluggedIn ? minutes(kIOPSTimeToFullChargeKey) : nil,
                cycleCount: health.cycleCount,
                healthPercent: health.healthPercent
            )
        }
        return nil
    }

    /// Cycle count and health from the AppleSmartBattery registry entry.
    private static func readSmartBattery() -> (cycleCount: Int?, healthPercent: Int?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        func intProperty(_ key: String) -> Int? {
            guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() else { return nil }
            return (value as? NSNumber)?.intValue
        }

        let cycles = intProperty("CycleCount")
        var health: Int?
        if let design = intProperty("DesignCapacity"), design > 0 {
            let full = intProperty("AppleRawMaxCapacity") ?? intProperty("MaxCapacity")
            if let full, full > 0 {
                health = Int((Double(full) / Double(design) * 100).rounded())
                if let h = health, h > 100 { health = 100 }
            }
        }
        return (cycles, health)
    }

    private static func readSimulated() -> BatterySnapshot? {
        guard let raw = ProcessInfo.processInfo.environment["BLS_SIMULATE"] else { return nil }
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard let first = parts.first, let level = Int(first) else { return nil }
        let plugged = parts.count > 1 && (parts[1] == "ac" || parts[1] == "plugged")
        return BatterySnapshot(
            level: level,
            isPluggedIn: plugged,
            isCharging: plugged && level < 100,
            isCharged: plugged && level >= 100,
            minutesToEmpty: plugged ? nil : level * 6,
            minutesToFull: plugged ? (100 - level) * 2 : nil,
            cycleCount: 137,
            healthPercent: 93
        )
    }
}
