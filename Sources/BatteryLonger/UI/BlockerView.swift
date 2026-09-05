import SwiftUI

/// Full-screen enforcement surface. There is no dismiss button: the only exit is
/// fixing the battery state (or the 5-second emergency hold to quit the app entirely).
struct BlockerView: View {
    @ObservedObject var engine: EnforcementEngine
    @ObservedObject private var l10n = Localization.shared
    var emergencyQuit: () -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var pulse = false

    private var violation: Violation { engine.phase.violation ?? .overcharge }
    private var accent: Color { violation == .overcharge ? Theme.caution : Theme.danger }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.55))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulse ? 1.08 : 0.94)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: violation.symbolName)
                        .font(.system(size: 84, weight: .bold))
                        .foregroundStyle(accent)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(spacing: 10) {
                    Text(violation.title.uppercased())
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                    Text(violation.instruction)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: 560)
                }

                VStack(spacing: 14) {
                    BatteryReadout(snapshot: engine.snapshot, phase: engine.phase, large: true)
                        .foregroundStyle(.white)
                    BatteryRangeGauge(snapshot: engine.snapshot)
                        .colorScheme(.dark)
                }
                .padding(28)
                .frame(maxWidth: 620)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )

                Label(resolveHint, systemImage: "arrow.uturn.backward.circle")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                emergency
                    .padding(.bottom, 32)
            }
            .padding(40)
        }
        .onAppear { pulse = true }
    }

    private var resolveHint: String {
        switch violation {
        case .overcharge: return L("blocker.hint.over")
        case .undercharge: return L("blocker.hint.under")
        }
    }

    /// Hold for 5 seconds to quit the app. Deliberately small and slow.
    private var emergency: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08)).frame(width: 220, height: 30)
                Capsule().fill(Theme.danger.opacity(0.55)).frame(width: 220 * holdProgress, height: 30)
                Text(holdProgress > 0 ? L("blocker.emergency.holding", Int((1 - holdProgress) * 5) + 1) : L("blocker.emergency.idle"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 220)
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startHold() }
                    .onEnded { _ in cancelHold() }
            )
            Text(L("blocker.emergency.note"))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func startHold() {
        guard holdTimer == nil else { return }
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            holdProgress = min(1, holdProgress + 0.05 / 5)
            if holdProgress >= 1 {
                cancelHold()
                emergencyQuit()
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
    }
}
