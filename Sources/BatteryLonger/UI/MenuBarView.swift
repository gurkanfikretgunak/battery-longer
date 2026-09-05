import SwiftUI

/// Content of the menu bar panel.
struct MenuBarView: View {
    @ObservedObject var engine: EnforcementEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject private var l10n = Localization.shared
    let device: DeviceGuard.Report
    var openSettings: () -> Void
    var showOnboarding: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            BatteryRangeGauge(snapshot: engine.snapshot)
            statusMessage
            Divider()
            EnforcementTimeline(engine: engine)
                .padding(.top, 2)
            Divider()
            stats
            CapacityBar(snapshot: engine.snapshot)
                .padding(.top, 2)
            Divider()
            controls
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(L("panel.title"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text(device.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            BatteryReadout(snapshot: engine.snapshot, phase: engine.phase)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch engine.phase {
        case .healthy:
            HStack(spacing: 8) {
                Image(systemName: engine.snapshot.isPluggedIn ? "powerplug.fill" : "battery.100percent")
                    .foregroundStyle(Theme.mint)
                Text(healthyText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .warned(let violation, _):
            HStack(spacing: 10) {
                CountdownRing(remaining: engine.secondsRemaining, total: Policy.graceInterval, size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(violation.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.caution)
                    Text(L("panel.warned.body"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Theme.caution.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .enforcing(let violation, let since):
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.danger)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("panel.enforcing.title", violation.title))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.danger)
                    Text(L("panel.enforcing.body", Self.timeFormatter.string(from: since)))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var healthyText: String {
        let s = engine.snapshot
        if s.isPluggedIn {
            if s.isCharging {
                let room = Policy.highThreshold - s.level
                return room > 0
                    ? L("panel.healthy.charging.room", room, Policy.highThreshold)
                    : L("panel.healthy.charging.atLimit", Policy.highThreshold)
            }
            return L("panel.healthy.held")
        } else {
            return L("panel.healthy.battery", s.level - Policy.lowThreshold, Policy.lowThreshold)
        }
    }

    private var stats: some View {
        let s = engine.snapshot
        return HStack(spacing: 0) {
            stat(L("stat.source"), s.isPluggedIn ? L("stat.source.adapter") : L("stat.source.battery"),
                 s.isPluggedIn ? "powerplug.fill" : "minus.plus.batteryblock.fill")
            stat(L("stat.time"), timeText, s.isPluggedIn ? "clock.arrow.circlepath" : "hourglass")
            stat(L("stat.cycles"), s.cycleCount.map { "\($0)" } ?? "–", "arrow.triangle.2.circlepath")
            stat(L("stat.health"), s.healthPercent.map { "\($0)%" } ?? "–", "heart.fill")
        }
    }

    private var timeText: String {
        let s = engine.snapshot
        let minutes = s.isPluggedIn ? s.minutesToFull : s.minutesToEmpty
        guard let minutes else { return "–" }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mint)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                openSettings()
            } label: {
                Label(L("panel.settings"), systemImage: "gearshape.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(",", modifiers: .command)

            Text(L("panel.rule.summary", Policy.lowThreshold, Policy.highThreshold, Policy.formattedGrace))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text(L("panel.stats", settings.warningCount, settings.enforcementCount))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Button(L("panel.quit")) { quit() }
                .buttonStyle(.link)
                .font(.system(size: 11))
                .disabled(engine.phase.isEnforcing)
                .help(engine.phase.isEnforcing ? L("panel.quit.help.locked") : L("panel.quit.help"))
        }
        .font(.system(size: 11))
    }
}
