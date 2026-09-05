import AppKit
import SwiftUI
import Combine

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let engine: EnforcementEngine
    private let showOnboarding: () -> Void
    private var cancellable: AnyCancellable?

    init(engine: EnforcementEngine, showOnboarding: @escaping () -> Void) {
        self.engine = engine
        self.showOnboarding = showOnboarding
        super.init()
        cancellable = Localization.shared.$resolved
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.window?.title = L("settings.title") }
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsView(settings: AppSettings.shared, engine: engine, showOnboarding: showOnboarding)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = L("settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
