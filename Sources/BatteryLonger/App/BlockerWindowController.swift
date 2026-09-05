import AppKit
import SwiftUI

/// Puts an un-dismissable panel on every screen while a violation is being enforced.
@MainActor
final class BlockerWindowController {
    private let engine: EnforcementEngine
    private let emergencyQuit: () -> Void
    private var windows: [NSWindow] = []
    private var reassertTimer: Timer?
    private var screenObserver: Any?
    private var didRequestSleep = false

    private(set) var isActive = false

    init(engine: EnforcementEngine, emergencyQuit: @escaping () -> Void) {
        self.engine = engine
        self.emergencyQuit = emergencyQuit
    }

    func activate(for violation: Violation) {
        guard !isActive else { return }
        isActive = true
        didRequestSleep = false
        buildWindows()

        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableHideApplication,
            .disableSessionTermination,
        ]

        reassertTimer = Timer.scheduledTimer(withTimeInterval: Policy.blockerReassertInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reassert() }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                self.tearDownWindows()
                self.buildWindows()
            }
        }

        if violation == .undercharge && AppSettings.shared.sleepOnLowBattery {
            requestSleepOnce()
        }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        reassertTimer?.invalidate()
        reassertTimer = nil
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        NSApp.presentationOptions = []
        tearDownWindows()
    }

    // MARK: - Windows

    private func buildWindows() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.hidesOnDeactivate = false
            window.animationBehavior = .none

            let view = BlockerView(engine: engine, emergencyQuit: emergencyQuit)
            window.contentView = NSHostingView(rootView: view)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            window.makeKey()
            windows.append(window)
        }
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func tearDownWindows() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        windows.removeAll()
    }

    private func reassert() {
        guard isActive else { return }
        if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
        for window in windows where !window.isVisible || !window.isOnActiveSpace {
            window.orderFrontRegardless()
        }
        windows.first?.makeKey()
    }

    private func requestSleepOnce() {
        guard !didRequestSleep else { return }
        didRequestSleep = true
        // Give the blocker a moment to appear so the user sees *why* the Mac slept.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["sleepnow"]
            do {
                try process.run()
                Log.info("Requested system sleep (low battery enforcement)")
            } catch {
                Log.error("pmset sleepnow failed: \(error.localizedDescription)")
            }
        }
    }
}
