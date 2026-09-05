import Foundation

/// The single source of truth for the 20–80 rule and the enforcement timeline.
///
/// Timeline for a violation:
///   t = 0s      → violation detected, user is warned exactly once
///   t = 120s    → still violating → enforcement starts (screen is blocked)
///   resolved    → everything resets immediately
enum Policy {
    /// Below this level (while unplugged) the battery is being drained too deep.
    static var lowThreshold: Int { AppSettings.shared.lowThreshold }
    /// Above this level (while plugged in) the battery is being charged too high.
    static var highThreshold: Int { AppSettings.shared.highThreshold }

    /// How long the user gets after the single warning before enforcement kicks in.
    /// `BLS_GRACE_SECONDS` (dev/testing) overrides the user setting.
    static var graceInterval: TimeInterval {
        if let raw = ProcessInfo.processInfo.environment["BLS_GRACE_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            return seconds
        }
        return TimeInterval(AppSettings.shared.graceSeconds)
    }

    static var formattedGrace: String {
        let s = Int(graceInterval)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Safety-net polling interval. IOKit notifications are the primary signal.
    static let pollInterval: TimeInterval = 5

    /// While enforcing, the blocker re-asserts itself this often.
    static let blockerReassertInterval: TimeInterval = 1
}

/// Which side of the safe range is being violated.
enum Violation: Equatable {
    /// Plugged in and at/above the high threshold: unplug the charger.
    case overcharge
    /// Unplugged and at/below the low threshold: plug the charger in.
    case undercharge

    var title: String {
        switch self {
        case .overcharge: return L("violation.over.title")
        case .undercharge: return L("violation.under.title")
        }
    }

    var instruction: String {
        switch self {
        case .overcharge: return L("violation.over.instruction", Policy.highThreshold)
        case .undercharge: return L("violation.under.instruction", Policy.lowThreshold)
        }
    }

    var symbolName: String {
        switch self {
        case .overcharge: return "bolt.slash.fill"
        case .undercharge: return "bolt.fill"
        }
    }
}

/// The enforcement state machine phases.
enum Phase: Equatable {
    case healthy
    case warned(Violation, deadline: Date)
    case enforcing(Violation, since: Date)

    var violation: Violation? {
        switch self {
        case .healthy: return nil
        case .warned(let v, _), .enforcing(let v, _): return v
        }
    }

    var isEnforcing: Bool {
        if case .enforcing = self { return true }
        return false
    }

    var isWarned: Bool {
        if case .warned = self { return true }
        return false
    }
}
