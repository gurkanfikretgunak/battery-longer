import SwiftUI

/// Settings window content. Grouped form with live preview of the rule.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var engine: EnforcementEngine
    @ObservedObject private var l10n = Localization.shared
    var showOnboarding: () -> Void

    @State private var launchAtLogin = AppSettings.shared.launchAtLogin

    private var graceMinutes: Binding<Double> {
        Binding(
            get: { Double(settings.graceSeconds) / 60 },
            set: { settings.graceSeconds = Int(($0 * 60).rounded()) }
        )
    }

    private var lowBinding: Binding<Double> {
        Binding(get: { Double(settings.lowThreshold) }, set: { settings.lowThreshold = Int($0.rounded()) })
    }

    private var highBinding: Binding<Double> {
        Binding(get: { Double(settings.highThreshold) }, set: { settings.highThreshold = Int($0.rounded()) })
    }

    var body: some View {
        Form {
            Section {
                OnboardingBanner(action: showOnboarding)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            ruleSection
            timingSection
            warningSection
            enforcementSection
            generalSection
            statsSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 720)
    }

    // MARK: Sections

    private var ruleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                BatteryRangeGauge(snapshot: previewSnapshot)
                    .padding(.top, 4)

                LabeledContent {
                    HStack {
                        Slider(value: lowBinding,
                               in: Double(AppSettings.Bounds.lowThreshold.lowerBound)...Double(AppSettings.Bounds.lowThreshold.upperBound),
                               step: 1)
                        Text("\(settings.lowThreshold)%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(Theme.danger)
                    }
                } label: {
                    Text(L("settings.rule.low"))
                    Text(L("settings.rule.low.desc"))
                }

                LabeledContent {
                    HStack {
                        Slider(value: highBinding,
                               in: Double(AppSettings.Bounds.highThreshold.lowerBound)...Double(AppSettings.Bounds.highThreshold.upperBound),
                               step: 1)
                        Text("\(settings.highThreshold)%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(Theme.caution)
                    }
                } label: {
                    Text(L("settings.rule.high"))
                    Text(L("settings.rule.high.desc"))
                }

                HStack {
                    Text(L("settings.rule.note", AppSettings.Defaults.lowThreshold, AppSettings.Defaults.highThreshold, AppSettings.Bounds.minimumBand))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("settings.rule.reset")) { settings.resetRuleToDefaults() }
                        .disabled(settings.isRuleDefault)
                }
            }
        } header: {
            Label(L("settings.rule"), systemImage: "ruler")
        }
    }

    private var timingSection: some View {
        Section {
            LabeledContent {
                HStack {
                    Slider(value: graceMinutes,
                           in: Double(AppSettings.Bounds.graceSeconds.lowerBound) / 60...Double(AppSettings.Bounds.graceSeconds.upperBound) / 60,
                           step: Double(AppSettings.Bounds.graceStep) / 60)
                    Text(Policy.formattedGrace)
                        .monospacedDigit()
                        .fontWeight(.semibold)
                        .frame(width: 44, alignment: .trailing)
                }
            } label: {
                Text(L("settings.timing.grace"))
                Text(L("settings.timing.grace.desc"))
            }

            HStack(spacing: 6) {
                ForEach([60, 120, 300, 600], id: \.self) { s in
                    Button(String(format: "%d:%02d", s / 60, s % 60)) { settings.graceSeconds = s }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(settings.graceSeconds == s ? Theme.mint : nil)
                }
                Spacer()
            }

            if engine.phase.isWarned {
                Label(L("settings.timing.active"), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label(L("settings.timing"), systemImage: "timer")
        }
    }

    private var warningSection: some View {
        Section {
            Toggle(isOn: $settings.playSound) {
                Text(L("settings.warning.sound"))
                Text(L("settings.warning.sound.desc"))
            }
            Toggle(isOn: $settings.openPanelOnWarning) {
                Text(L("settings.warning.panel"))
                Text(L("settings.warning.panel.desc"))
            }
            LabeledContent {
                Button(L("settings.warning.openSystem")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } label: {
                Text(L("settings.warning.permission"))
                Text(L("settings.warning.permission.desc"))
            }
        } header: {
            Label(L("settings.warning"), systemImage: "bell.badge")
        }
    }

    private var enforcementSection: some View {
        Section {
            Toggle(isOn: $settings.sleepOnLowBattery) {
                Text(L("settings.enforce.sleep"))
                Text(L("settings.enforce.sleep.desc"))
            }
            LabeledContent {
                Text(L("settings.enforce.off"))
                    .foregroundStyle(.secondary)
            } label: {
                Text(L("settings.enforce.snooze"))
                Text(L("settings.enforce.snooze.desc"))
            }
        } header: {
            Label(L("settings.enforce"), systemImage: "lock.shield")
        }
    }

    private var generalSection: some View {
        Section {
            LabeledContent(L("settings.general.language")) {
                LanguagePicker()
                    .frame(width: 160)
            }
            if settings.canManageLoginItem {
                Toggle(isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        launchAtLogin = settings.launchAtLogin
                    }
                )) {
                    Text(L("settings.general.login"))
                    Text(L("settings.general.login.desc"))
                }
            }
            Toggle(isOn: $settings.showPercentInMenuBar) {
                Text(L("settings.general.percent"))
                Text(L("settings.general.percent.desc"))
            }
        } header: {
            Label(L("settings.general"), systemImage: "gearshape")
        }
    }

    private var statsSection: some View {
        Section {
            LabeledContent(L("settings.stats.warnings"), value: "\(settings.warningCount)")
            LabeledContent(L("settings.stats.locks"), value: "\(settings.enforcementCount)")
            HStack {
                Spacer()
                Button(L("settings.stats.reset")) { settings.resetStats() }
                    .disabled(settings.warningCount == 0 && settings.enforcementCount == 0)
            }
        } header: {
            Label(L("settings.stats"), systemImage: "chart.bar")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent(L("about.author")) {
                Link(destination: Credits.authorGitHub) {
                    Label("\(Credits.authorName) · @\(Credits.authorHandle)", systemImage: "arrow.up.right.square")
                        .labelStyle(TrailingIconLabelStyle())
                }
            }
            LabeledContent(L("about.company")) {
                Link(destination: Credits.companyGitHub) {
                    Label("\(Credits.companyName) · @\(Credits.companyHandle)", systemImage: "arrow.up.right.square")
                        .labelStyle(TrailingIconLabelStyle())
                }
            }
            LabeledContent(L("about.source")) {
                Link(destination: Credits.repository) {
                    Label("github.com/\(Credits.repositoryPath)", systemImage: "arrow.up.right.square")
                        .labelStyle(TrailingIconLabelStyle())
                }
            }
        } header: {
            Label(L("about"), systemImage: "info.circle")
        } footer: {
            Text("\(L("settings.footer", Credits.version)) · \(Credits.copyright)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private struct TrailingIconLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 4) {
                configuration.title
                configuration.icon.font(.system(size: 10))
            }
        }
    }

    private var previewSnapshot: BatterySnapshot {
        engine.snapshot.level > 0 ? engine.snapshot
            : BatterySnapshot(level: 55, isPluggedIn: false, isCharging: false, isCharged: false)
    }
}
