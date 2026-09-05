import Foundation
import Combine

/// The heart of the app: turns battery snapshots into a strict, predictable timeline.
///
///     healthy ──violation──▶ warned (single warning, 2:00 countdown)
///        ▲                       │ still violating after the countdown
///        │                       ▼
///        └───────resolved──── enforcing (screen blocked until fixed)
///
/// The engine never snoozes, never re-warns, and never negotiates. The only way out
/// of `warned` or `enforcing` is to bring the battery back inside 20–80.
@MainActor
final class EnforcementEngine: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot = .unknown
    @Published private(set) var phase: Phase = .healthy
    /// Seconds left in the grace period while `warned`, otherwise 0.
    @Published private(set) var secondsRemaining: Int = 0

    /// Side effects, wired by the app delegate.
    var onWarn: ((Violation, BatterySnapshot) -> Void)?
    var onEnforce: ((Violation, BatterySnapshot) -> Void)?
    var onResolve: ((BatterySnapshot) -> Void)?

    private var ticker: Timer?
    private var lastResolvedAt: Date?

    /// Feed a new reading. Safe to call as often as you like.
    func ingest(_ newSnapshot: BatterySnapshot) {
        snapshot = newSnapshot
        let now = Date()

        guard let violation = newSnapshot.violation else {
            resolveIfNeeded(with: newSnapshot)
            return
        }

        switch phase {
        case .healthy:
            let deadline = now.addingTimeInterval(Policy.graceInterval)
            phase = .warned(violation, deadline: deadline)
            secondsRemaining = Int(Policy.graceInterval.rounded())
            Log.info("WARN \(violation) at \(newSnapshot.level)% – enforcement at \(deadline)")
            AppSettings.shared.recordWarning()
            startTicker()
            onWarn?(violation, newSnapshot)

        case .warned(let current, let deadline):
            if current != violation {
                // Flipped from one side of the range to the other without passing through
                // the safe zone (practically impossible, but keep the machine total).
                phase = .healthy
                ingest(newSnapshot)
                return
            }
            if now >= deadline {
                escalate(violation, snapshot: newSnapshot)
            } else {
                secondsRemaining = max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
            }

        case .enforcing(let current, _):
            if current != violation {
                phase = .healthy
                ingest(newSnapshot)
            }
        }
    }

    private func escalate(_ violation: Violation, snapshot: BatterySnapshot) {
        phase = .enforcing(violation, since: Date())
        secondsRemaining = 0
        Log.info("ENFORCE \(violation) at \(snapshot.level)%")
        AppSettings.shared.recordEnforcement()
        onEnforce?(violation, snapshot)
    }

    private func resolveIfNeeded(with snapshot: BatterySnapshot) {
        guard phase != .healthy else { return }
        Log.info("RESOLVED at \(snapshot.level)% (plugged: \(snapshot.isPluggedIn))")
        phase = .healthy
        secondsRemaining = 0
        lastResolvedAt = Date()
        stopTicker()
        onResolve?(snapshot)
    }

    // MARK: - Ticker (drives the countdown UI and the deadline check)

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        switch phase {
        case .warned(let violation, let deadline):
            let now = Date()
            if now >= deadline {
                // Re-check against the latest snapshot before escalating.
                if snapshot.violation == violation {
                    escalate(violation, snapshot: snapshot)
                } else {
                    resolveIfNeeded(with: snapshot)
                }
            } else {
                secondsRemaining = max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
            }
        case .enforcing:
            // Nothing to count; the blocker controller re-asserts itself.
            break
        case .healthy:
            stopTicker()
        }
    }

    // MARK: - Derived

    var formattedRemaining: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}
