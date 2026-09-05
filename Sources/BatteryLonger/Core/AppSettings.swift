import Foundation
import ServiceManagement

/// Persisted user preferences.
///
/// The rule stays strict by design, but its knobs are adjustable within sane bounds:
///   • grace period      1 – 10 min   (default 2:00)
///   • low threshold    10 – 30 %     (default 20)
///   • high threshold   70 – 95 %     (default 80)
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: Bounds & defaults

    enum Defaults {
        static let graceSeconds = 120
        static let lowThreshold = 20
        static let highThreshold = 80
    }

    enum Bounds {
        static let graceSeconds: ClosedRange<Int> = 60...600          // 1 – 10 min
        static let graceStep = 30                                     // 30 s granularity
        static let lowThreshold: ClosedRange<Int> = 10...30
        static let highThreshold: ClosedRange<Int> = 70...95
        /// Keep a meaningful safe band between the two thresholds.
        static let minimumBand = 30
    }

    private let defaults = UserDefaults.standard

    private enum Key {
        static let onboardingCompleted = "onboardingCompleted"
        static let sleepOnLowBattery = "sleepOnLowBattery"
        static let playSound = "playSound"
        static let openPanelOnWarning = "openPanelOnWarning"
        static let showPercentInMenuBar = "showPercentInMenuBar"
        static let graceSeconds = "graceSeconds"
        static let lowThreshold = "lowThreshold"
        static let highThreshold = "highThreshold"
        static let enforcementCount = "enforcementCount"
        static let warningCount = "warningCount"
    }

    // MARK: Rule

    /// Seconds between the single warning and enforcement.
    @Published var graceSeconds: Int {
        didSet {
            let clamped = Self.snap(graceSeconds, to: Bounds.graceStep, in: Bounds.graceSeconds)
            if clamped != graceSeconds { graceSeconds = clamped; return }
            defaults.set(graceSeconds, forKey: Key.graceSeconds)
        }
    }

    @Published var lowThreshold: Int {
        didSet {
            let clamped = min(max(lowThreshold, Bounds.lowThreshold.lowerBound),
                              min(Bounds.lowThreshold.upperBound, highThreshold - Bounds.minimumBand))
            if clamped != lowThreshold { lowThreshold = clamped; return }
            defaults.set(lowThreshold, forKey: Key.lowThreshold)
        }
    }

    @Published var highThreshold: Int {
        didSet {
            let clamped = max(min(highThreshold, Bounds.highThreshold.upperBound),
                              max(Bounds.highThreshold.lowerBound, lowThreshold + Bounds.minimumBand))
            if clamped != highThreshold { highThreshold = clamped; return }
            defaults.set(highThreshold, forKey: Key.highThreshold)
        }
    }

    var isRuleDefault: Bool {
        graceSeconds == Defaults.graceSeconds
            && lowThreshold == Defaults.lowThreshold
            && highThreshold == Defaults.highThreshold
    }

    func resetRuleToDefaults() {
        lowThreshold = Defaults.lowThreshold
        highThreshold = Defaults.highThreshold
        graceSeconds = Defaults.graceSeconds
    }

    // MARK: Behaviour

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    /// When enforcing an undercharge, also put the Mac to sleep so the last percent is preserved.
    @Published var sleepOnLowBattery: Bool {
        didSet { defaults.set(sleepOnLowBattery, forKey: Key.sleepOnLowBattery) }
    }

    @Published var playSound: Bool {
        didSet { defaults.set(playSound, forKey: Key.playSound) }
    }

    /// Pop the menu bar panel open automatically when the warning fires.
    @Published var openPanelOnWarning: Bool {
        didSet { defaults.set(openPanelOnWarning, forKey: Key.openPanelOnWarning) }
    }

    /// Show "72%" next to the menu bar icon (icon-only when off).
    @Published var showPercentInMenuBar: Bool {
        didSet { defaults.set(showPercentInMenuBar, forKey: Key.showPercentInMenuBar) }
    }

    // MARK: Stats

    @Published private(set) var warningCount: Int {
        didSet { defaults.set(warningCount, forKey: Key.warningCount) }
    }

    @Published private(set) var enforcementCount: Int {
        didSet { defaults.set(enforcementCount, forKey: Key.enforcementCount) }
    }

    func recordWarning() { warningCount += 1 }
    func recordEnforcement() { enforcementCount += 1 }
    func resetStats() { warningCount = 0; enforcementCount = 0 }

    // MARK: Init

    private init() {
        graceSeconds = defaults.object(forKey: Key.graceSeconds) as? Int ?? Defaults.graceSeconds
        lowThreshold = defaults.object(forKey: Key.lowThreshold) as? Int ?? Defaults.lowThreshold
        highThreshold = defaults.object(forKey: Key.highThreshold) as? Int ?? Defaults.highThreshold
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        sleepOnLowBattery = defaults.bool(forKey: Key.sleepOnLowBattery)
        playSound = defaults.object(forKey: Key.playSound) as? Bool ?? true
        openPanelOnWarning = defaults.object(forKey: Key.openPanelOnWarning) as? Bool ?? true
        showPercentInMenuBar = defaults.object(forKey: Key.showPercentInMenuBar) as? Bool ?? true
        warningCount = defaults.integer(forKey: Key.warningCount)
        enforcementCount = defaults.integer(forKey: Key.enforcementCount)
    }

    private static func snap(_ value: Int, to step: Int, in range: ClosedRange<Int>) -> Int {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return Int((Double(clamped) / Double(step)).rounded()) * step
    }

    // MARK: - Launch at login (only meaningful inside a real .app bundle)

    var canManageLoginItem: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    var launchAtLogin: Bool {
        get { canManageLoginItem && SMAppService.mainApp.status == .enabled }
        set {
            guard canManageLoginItem else { return }
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.error("Launch at login change failed: \(error.localizedDescription)")
            }
            objectWillChange.send()
        }
    }
}
