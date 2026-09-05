import SwiftUI

/// Clickable hero card that opens the introduction. Sketch artwork sits on the right,
/// bleeding behind the copy on the left.
struct OnboardingBanner: View {
    var action: () -> Void
    @ObservedObject private var l10n = Localization.shared
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                // Paper + mint wash
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.paper, Theme.mint.opacity(hovering ? 0.22 : 0.14)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )

                // Illustration, right-aligned, allowed to overflow behind the text
                HStack {
                    Spacer(minLength: 0)
                    SketchImage(path: "Onboarding/sketch-05-banner.png", flat: true)
                        .frame(height: 150)
                        .offset(x: 26, y: 8)
                        .opacity(0.95)
                }
                .clipped()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.28),
                            .init(color: .black, location: 0.55),
                            .init(color: .black, location: 1.0),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

                // Copy
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("banner.eyebrow").uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Theme.mint)
                    Text(L("banner.title"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("banner.subtitle"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        Text(L("banner.cta"))
                        Image(systemName: "arrow.right")
                            .offset(x: hovering ? 2 : 0)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Theme.mint, in: Capsule())
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: 300, alignment: .leading)
            }
            .frame(height: 132)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.mint.opacity(hovering ? 0.6 : 0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.mint.opacity(hovering ? 0.25 : 0.08), radius: hovering ? 14 : 6, y: 4)
            .scaleEffect(hovering ? 1.005 : 1)
            .animation(.easeOut(duration: 0.18), value: hovering)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(L("banner.title"))
    }
}
