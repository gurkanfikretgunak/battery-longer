import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = EnforcementEngine()
    private let monitor = BatteryMonitor()
    private var statusBar: StatusBarController?
    private var blocker: BlockerWindowController?
    private var onboarding: OnboardingWindowController?
    private var settingsWindow: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var device: DeviceGuard.Report!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        device = DeviceGuard.inspect()
        Log.info("Device: \(device.displayName) [\(device.modelIdentifier)] battery=\(device.hasInternalBattery)")
        guard device.isMacBook || ProcessInfo.processInfo.environment["BLS_SIMULATE"] != nil else {
            refuseNonMacBook()
            return
        }

        wire()
        monitor.start()
        let b = monitor.latest
        Log.info("Battery: \(b.level)% plugged=\(b.isPluggedIn) charging=\(b.isCharging) cycles=\(b.cycleCount.map(String.init) ?? "?") health=\(b.healthPercent.map(String.init) ?? "?")")

        if !AppSettings.shared.onboardingCompleted {
            showOnboarding()
        } else {
            Notifier.shared.requestAuthorization()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // While enforcing, ordinary quit paths are refused. The emergency hold bypasses this.
        if engine.phase.isEnforcing && !emergencyQuitRequested {
            Log.info("Quit refused during enforcement")
            return .terminateCancel
        }
        return .terminateNow
    }

    // MARK: - Wiring

    private var emergencyQuitRequested = false

    private func wire() {
        blocker = BlockerWindowController(engine: engine) { [weak self] in
            guard let self else { return }
            Log.info("Emergency quit")
            self.emergencyQuitRequested = true
            self.blocker?.deactivate()
            NSApp.terminate(nil)
        }

        settingsWindow = SettingsWindowController(engine: engine) { [weak self] in self?.showOnboarding() }

        statusBar = StatusBarController(
            engine: engine,
            device: device,
            openSettings: { [weak self] in
                self?.statusBar?.closePanel()
                self?.settingsWindow?.show()
            },
            showOnboarding: { [weak self] in self?.showOnboarding() },
            quit: { NSApp.terminate(nil) }
        )

        engine.onWarn = { [weak self] _, _ in
            guard let self else { return }
            Notifier.shared.warn(self.engine.phase.violation ?? .overcharge, snapshot: self.engine.snapshot)
            if AppSettings.shared.openPanelOnWarning { self.statusBar?.showPanel() }
        }
        engine.onEnforce = { [weak self] violation, _ in
            guard let self else { return }
            self.statusBar?.closePanel()
            self.blocker?.activate(for: violation)
        }

        // Thresholds changed in Settings → re-evaluate the current reading right away.
        AppSettings.shared.$lowThreshold
            .combineLatest(AppSettings.shared.$highThreshold)
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.engine.ingest(self.monitor.latest)
            }
            .store(in: &cancellables)
        engine.onResolve = { [weak self] snapshot in
            guard let self else { return }
            let wasEnforcing = self.blocker?.isActive ?? false
            self.blocker?.deactivate()
            if wasEnforcing { Notifier.shared.resolved(snapshot) }
        }

        monitor.onChange = { [weak self] snapshot in
            Task { @MainActor in self?.engine.ingest(snapshot) }
        }
    }

    private func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindowController { [weak self] in
                AppSettings.shared.onboardingCompleted = true
                Notifier.shared.requestAuthorization()
                self?.onboarding = nil
            }
        }
        onboarding?.show()
    }

    private func refuseNonMacBook() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = L("alert.notMacBook.title")
        alert.informativeText = L("alert.notMacBook.body", device.displayName)
        alert.addButton(withTitle: L("alert.close"))
        alert.runModal()
        NSApp.terminate(nil)
    }
}
