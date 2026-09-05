import SwiftUI

/// Clickable hero card that opens the introduction.
///
/// The card is always "paper" (light, mint-washed) regardless of the system appearance so the
/// pencil sketch – which has a white background – melts into it with a multiply blend instead
/// of sitting on the card as a hard white rectangle.
struct OnboardingBanner: View {
    var action: () -> Void
    @ObservedObject private var l10n = Localization.shared
    @State private var hovering = false

    private let radius: CGFloat = 16
    private let height: CGFloat = 140

    // Fixed palette: the card does not follow dark mode.
    private let paper = Color(red: 0.985, green: 0.985, blue: 0.975)
    private let paperMint = Color(red: 0.87, green: 0.95, blue: 0.91)
    private let paperMintHover = Color(red: 0.82, green: 0.94, blue: 0.88)
    private let ink = Color(red: 0.13, green: 0.15, blue: 0.16)
    private let inkSoft = Color(red: 0.38, green: 0.42, blue: 0.44)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                // Paper with a mint wash that strengthens toward the artwork
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: paper, location: 0),
                                .init(color: paper, location: 0.45),
                                .init(color: hovering ? paperMintHover : paperMint, location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )

                // Sketch, right-aligned, white paper knocked out by multiply, left edge feathered
                GeometryReader { geo in
                    SketchImage(path: "Onboarding/sketch-05-banner.png", flat: true)
                        .frame(height: geo.size.height * 1.04)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(x: 4, y: 0)
                        .blendMode(.multiply)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.56),
                                    .init(color: .black, location: 0.76),
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }

                // Copy
                VStack(alignment: .leading, spacing: 7) {
                    Text(L("banner.eyebrow").uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color(red: 0.16, green: 0.55, blue: 0.40))
                    Text(L("banner.title"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("banner.subtitle"))
                        .font(.system(size: 11))
                        .foregroundStyle(inkSoft)
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
                    .foregroundStyle(ink)
                    .padding(.top, 3)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 290, alignment: .leading)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.mint.opacity(hovering ? 0.75 : 0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(hovering ? 0.18 : 0.10), radius: hovering ? 14 : 8, y: 4)
            .scaleEffect(hovering ? 1.004 : 1)
            .animation(.easeOut(duration: 0.18), value: hovering)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(L("banner.title"))
        .environment(\.colorScheme, .light)
    }
}
