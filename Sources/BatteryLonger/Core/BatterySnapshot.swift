import Foundation

/// A point-in-time reading of the internal battery.
struct BatterySnapshot: Equatable {
    /// 0...100
    var level: Int
    /// External power (adapter) is connected.
    var isPluggedIn: Bool
    /// Energy is actively flowing into the cells.
    var isCharging: Bool
    /// macOS reports the battery as fully charged.
    var isCharged: Bool
    /// Minutes, if known.
    var minutesToEmpty: Int?
    /// Minutes, if known.
    var minutesToFull: Int?
    /// From AppleSmartBattery, if available.
    var cycleCount: Int?
    /// Current full-charge capacity as a percentage of design capacity.
    var healthPercent: Int?
    var timestamp: Date = Date()

    /// Applies the 20–80 rule to this reading.
    var violation: Violation? {
        if isPluggedIn {
            // Held at exactly 80 by Optimized Charging (not charging) is acceptable;
            // anything above 80, or actively charging at 80, is not.
            if level > Policy.highThreshold { return .overcharge }
            if level >= Policy.highThreshold && (isCharging || isCharged) { return .overcharge }
            return nil
        } else {
            if level <= Policy.lowThreshold { return .undercharge }
            return nil
        }
    }

    var isInsideSafeRange: Bool {
        level >= Policy.lowThreshold && level <= Policy.highThreshold
    }

    static let unknown = BatterySnapshot(
        level: 0, isPluggedIn: false, isCharging: false, isCharged: false,
        minutesToEmpty: nil, minutesToFull: nil, cycleCount: nil, healthPercent: nil
    )
}
