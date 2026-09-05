import SwiftUI

/// Visualizes the strict three-step story: Sapma → Uyarı (1 kez, 2:00) → Kilit.
struct EnforcementTimeline: View {
    @ObservedObject var engine: EnforcementEngine
    @ObservedObject private var l10n = Localization.shared

    private enum Step: Int, CaseIterable {
        case detect, warn, enforce

        var title: String {
            switch self {
            case .detect: return L("timeline.detect")
            case .warn: return L("timeline.warn")
            case .enforce: return L("timeline.enforce")
            }
        }

        var symbol: String {
            switch self {
            case .detect: return "waveform.path.ecg"
            case .warn: return "bell.badge.fill"
            case .enforce: return "lock.shield.fill"
            }
        }
    }

    private var activeIndex: Int {
        switch engine.phase {
        case .healthy: return -1
        case .warned: return 1
        case .enforcing: return 2
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Step.allCases, id: \.rawValue) { step in
                node(step)
                if step != .enforce {
                    connector(after: step)
                }
            }
        }
    }

    private func node(_ step: Step) -> some View {
        let reached = step.rawValue <= activeIndex
        let current = step.rawValue == activeIndex
        let color: Color = {
            switch step {
            case .detect: return Theme.mint
            case .warn: return Theme.caution
            case .enforce: return Theme.danger
            }
        }()

        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(reached ? color.opacity(0.18) : Color.primary.opacity(0.06))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle().strokeBorder(reached ? color : Color.primary.opacity(0.15),
                                              style: StrokeStyle(lineWidth: current ? 2 : 1, dash: reached ? [] : [3, 3]))
                    )
                Image(systemName: step.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(reached ? color : .secondary)
            }
            Text(step.title)
                .font(.system(size: 9, weight: current ? .bold : .medium, design: .rounded))
                .foregroundStyle(reached ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(minWidth: 62)
    }

    private func connector(after step: Step) -> some View {
        let filled = step.rawValue < activeIndex
        let countdownHere = step == .warn && engine.phase.isWarned
        return ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 2)
            if filled {
                Rectangle().fill(Theme.danger.opacity(0.6)).frame(height: 2)
            }
            if countdownHere {
                Text(engine.formattedRemaining)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.caution.opacity(0.18), in: Capsule())
                    .foregroundStyle(Theme.caution)
            } else if step == .warn {
                Text(Policy.formattedGrace)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.paper, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(y: -9)
    }
}

/// Circular countdown for the grace period.
struct CountdownRing: View {
    let remaining: Int
    let total: TimeInterval
    var size: CGFloat = 120
    var color: Color = Theme.caution
    @ObservedObject private var l10n = Localization.shared

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(remaining) / CGFloat(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: size * 0.08)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            VStack(spacing: 2) {
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(L("countdown.remaining"))
                    .font(.system(size: size * 0.10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
