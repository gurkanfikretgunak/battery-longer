import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let sketch: String

    // Copy is resolved at render time so language switches apply immediately.
    private var n: Int { id + 1 }
    var eyebrow: String { L("onb.\(n).eyebrow") }
    var title: String { L("onb.\(n).title") }
    var body: String { L("onb.\(n).body") }
    var bullets: [String] { (1...3).map { L("onb.\(n).b\($0)") } }
}

enum OnboardingContent {
    static let pages: [OnboardingPage] = [
        OnboardingPage(id: 0, sketch: "Onboarding/sketch-01-range.png"),
        OnboardingPage(id: 1, sketch: "Onboarding/sketch-02-warning.png"),
        OnboardingPage(id: 2, sketch: "Onboarding/sketch-03-enforce.png"),
        OnboardingPage(id: 3, sketch: "Onboarding/sketch-04-health.png"),
    ]
}

struct OnboardingView: View {
    var finish: () -> Void

    @State private var index = 0
    @ObservedObject private var l10n = Localization.shared
    private let pages = OnboardingContent.pages

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(pages) { page in
                    if page.id == index {
                        pageView(page)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: index)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .frame(width: 760, height: 560)
        .background(Theme.paper)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        HStack(spacing: 0) {
            SketchImage(path: page.sketch)
                .frame(width: 400)
                .padding(28)

            VStack(alignment: .leading, spacing: 14) {
                Text(page.eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.mint)
                Text(page.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(page.body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(page.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.mint)
                                .font(.system(size: 12))
                                .padding(.top, 2)
                            Text(bullet)
                                .font(.system(size: 12, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 4)

                if page.id == 0 {
                    BatteryRangeGauge(snapshot: BatterySnapshot(level: 64, isPluggedIn: false, isCharging: false, isCharged: false))
                        .padding(.top, 8)
                }
                Spacer()
            }
            .padding(.trailing, 36)
            .padding(.top, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(pages) { page in
                    Capsule()
                        .fill(page.id == index ? Theme.mint : Color.primary.opacity(0.15))
                        .frame(width: page.id == index ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.3), value: index)
                }
            }
            Spacer()
            languagePicker
            if index > 0 {
                Button(L("onb.back")) { index -= 1 }
                    .keyboardShortcut(.leftArrow, modifiers: [])
            }
            if index < pages.count - 1 {
                Button(L("onb.next")) { index += 1 }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.mint)
            } else {
                Button(L("onb.finish")) { finish() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.mint)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.bar)
    }

    private var languagePicker: some View {
        LanguagePicker(compact: true)
            .frame(width: 150)
    }
}

/// Language selector shared by onboarding and settings.
struct LanguagePicker: View {
    var compact: Bool = false
    @ObservedObject private var l10n = Localization.shared

    var body: some View {
        HStack(spacing: 6) {
            if compact {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
            }
            Picker(L("settings.general.language"), selection: $l10n.language) {
                ForEach(Language.allCases) { lang in
                    Text(lang.nativeName).tag(lang)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

/// Loads a sketch from Resources; if it is missing, draws a simple placeholder in the same spirit.
struct SketchImage: View {
    let path: String
    /// `flat` renders the artwork without the card treatment (used inside banners).
    var flat: Bool = false

    var body: some View {
        if let image = AppResources.image(path) {
            if flat {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            }
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.mint, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "scribble.variable")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.mint)
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                )
        }
    }
}
