import AppKit
import SwiftUI
import Combine

/// Owns the NSStatusItem and the detached panel that drops down beneath it.
///
/// Instead of an NSPopover glued to the menu bar, the panel is a floating, rounded
/// card that opens `panelGap` points *below* the menu bar – a small breath of air –
/// and closes on outside click or Esc. Right-click shows a compact context menu.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let engine: EnforcementEngine
    private let panel: StatusPanel
    private let hosting: NSHostingView<MenuBarView>
    private var cancellables = Set<AnyCancellable>()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private let openSettings: () -> Void
    private let showOnboarding: () -> Void
    private let quit: () -> Void

    /// Space between the bottom of the menu bar and the top of the panel.
    private let panelGap: CGFloat = 8

    init(
        engine: EnforcementEngine,
        device: DeviceGuard.Report,
        openSettings: @escaping () -> Void,
        showOnboarding: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.engine = engine
        self.openSettings = openSettings
        self.showOnboarding = showOnboarding
        self.quit = quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let root = MenuBarView(
            engine: engine,
            settings: AppSettings.shared,
            device: device,
            openSettings: openSettings,
            showOnboarding: showOnboarding,
            quit: quit
        )
        hosting = NSHostingView(rootView: root)
        panel = StatusPanel(contentView: hosting)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        engine.$snapshot
            .combineLatest(engine.$phase, engine.$secondsRemaining, AppSettings.shared.$showPercentInMenuBar)
            .combineLatest(Localization.shared.$resolved)
            .receive(on: RunLoop.main)
            .sink { [weak self] tuple, _ in
                let (snapshot, phase, seconds, showPercent) = tuple
                self?.render(snapshot: snapshot, phase: phase, seconds: seconds, showPercent: showPercent)
            }
            .store(in: &cancellables)

        // Content height changes with phase; keep the panel hugging its content.
        engine.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.panel.isVisible else { return }
                DispatchQueue.main.async { self.layoutPanel(animated: true) }
            }
            .store(in: &cancellables)
    }

    // MARK: Rendering

    private func render(snapshot: BatterySnapshot, phase: Phase, seconds: Int, showPercent: Bool) {
        guard let button = statusItem.button else { return }

        let symbol: String
        let tint: NSColor
        var title: String

        switch phase {
        case .healthy:
            symbol = batterySymbol(for: snapshot)
            tint = NSColor(Theme.mint)
            title = showPercent ? "\(snapshot.level)%" : ""
        case .warned:
            symbol = "exclamationmark.triangle.fill"
            tint = NSColor(Theme.caution)
            title = String(format: "%d:%02d", seconds / 60, seconds % 60)
        case .enforcing:
            symbol = "lock.fill"
            tint = NSColor(Theme.danger)
            title = "\(snapshot.level)%"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [tint]))
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
            .withSymbolConfiguration(config)
        image?.isTemplate = false
        button.image = image

        if !title.isEmpty { title = " " + title }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: phase == .healthy ? .medium : .bold)
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font, .foregroundColor: phase == .healthy ? NSColor.labelColor : tint]
        )
        button.toolTip = phase.violation?.instruction ?? L("menubar.tooltip.safe", Policy.lowThreshold, Policy.highThreshold)
    }

    private func batterySymbol(for s: BatterySnapshot) -> String {
        if s.isPluggedIn { return s.isCharging ? "battery.100percent.bolt" : "powerplug.fill" }
        switch s.level {
        case 0..<13: return "battery.0percent"
        case 13..<38: return "battery.25percent"
        case 38..<63: return "battery.50percent"
        case 63..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    // MARK: Click handling

    @objc private func statusItemClicked(_ sender: Any?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        togglePanel()
    }

    private func showContextMenu() {
        closePanel()
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: L("menu.settings"), action: #selector(menuSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L("menu.onboarding"), action: #selector(menuOnboarding), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: L("menu.quit"), action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = !engine.phase.isEnforcing
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Detach so the next left-click opens the panel instead of the menu.
        statusItem.menu = nil
    }

    @objc private func menuSettings() { openSettings() }
    @objc private func menuOnboarding() { showOnboarding() }
    @objc private func menuQuit() { quit() }

    // MARK: Panel

    func togglePanel() {
        if panel.isVisible { closePanel() } else { showPanel() }
    }

    func showPanel() {
        guard !panel.isVisible else { return }
        layoutPanel(animated: false)
        statusItem.button?.highlight(true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.closePanel(); return nil }   // Esc
                return event
            }
            if event.window !== self.panel && event.window !== self.statusItem.button?.window {
                self.closePanel()
            }
            return event
        }
    }

    func closePanel() {
        guard panel.isVisible else { return }
        statusItem.button?.highlight(false)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    /// Positions the panel centred under the status item, `panelGap` points below the menu bar,
    /// clamped to the screen's visible frame.
    private func layoutPanel(animated: Bool) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? buttonRect

        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        var origin = NSPoint(
            x: buttonRect.midX - size.width / 2,
            y: buttonRect.minY - panelGap - size.height
        )
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = max(origin.y, visible.minY + 8)

        let frame = NSRect(origin: origin, size: size)
        panel.setFrame(frame, display: true, animate: animated && panel.isVisible)
    }
}

/// Borderless, non-activating floating card with rounded corners and a material background.
final class StatusPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        animationBehavior = .none

        let card = NSVisualEffectView()
        card.material = .popover
        card.blendingMode = .behindWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.cornerCurve = .continuous
        card.layer?.masksToBounds = true
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: card.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        self.contentView = card
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
