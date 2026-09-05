import SwiftUI

/// The core "logical" visual of the product: a 0–100 track with the 20–80 safe band,
/// the two danger zones, and a live marker showing where the battery is right now.
struct BatteryRangeGauge: View {
    let snapshot: BatterySnapshot
    var compact: Bool = false
    @ObservedObject private var l10n = Localization.shared

    private var low: CGFloat { CGFloat(Policy.lowThreshold) / 100 }
    private var high: CGFloat { CGFloat(Policy.highThreshold) / 100 }
    private var level: CGFloat { CGFloat(min(100, max(0, snapshot.level))) / 100 }

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .leading) {
                    // Zones
                    HStack(spacing: 0) {
                        zone(Theme.danger, width: w * low)
                        zone(Theme.mint, width: w * (high - low))
                        zone(Theme.caution, width: w * (1 - high))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: h / 2, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: h / 2, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                    // Threshold ticks
                    tick(at: w * low, height: h)
                    tick(at: w * high, height: h)

                    // Direction of travel
                    if snapshot.isPluggedIn && snapshot.isCharging {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: h * 0.45, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .offset(x: min(w - h, w * level + 6))
                    } else if !snapshot.isPluggedIn {
                        Image(systemName: "chevron.left.2")
                            .font(.system(size: h * 0.45, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .offset(x: max(2, w * level - h))
                    }

                    // Live marker
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 4, height: h + 8)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .overlay(
                            Capsule().strokeBorder(Theme.zoneColor(for: snapshot.level), lineWidth: 1.5)
                        )
                        .offset(x: w * level - 2, y: 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: snapshot.level)
                }
            }
            .frame(height: compact ? 14 : 22)

            HStack {
                Text("0")
                Spacer()
                Text("\(Policy.lowThreshold)")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.danger)
                Spacer()
                Text(L("gauge.safe"))
                    .foregroundStyle(Theme.mint)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Policy.highThreshold)")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.caution)
                Spacer()
                Text("100")
            }
            .font(.system(size: compact ? 9 : 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private func zone(_ color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(colors: [color.opacity(0.95), color.opacity(0.75)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: max(0, width))
    }

    private func tick(at x: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.9))
            .frame(width: 1.5, height: height)
            .offset(x: x - 0.75)
    }
}

/// Big numeric readout with state pill, used in popover header and blocker.
struct BatteryReadout: View {
    let snapshot: BatterySnapshot
    let phase: Phase
    var large: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(snapshot.level)")
                .font(.system(size: large ? 96 : 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("%")
                .font(.system(size: large ? 40 : 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            StatePill(phase: phase, snapshot: snapshot, large: large)
        }
    }
}

struct StatePill: View {
    let phase: Phase
    let snapshot: BatterySnapshot
    var large: Bool = false
    @ObservedObject private var l10n = Localization.shared

    private var label: (text: String, color: Color, symbol: String) {
        switch phase {
        case .healthy:
            if snapshot.isPluggedIn && !snapshot.isCharging && snapshot.level >= Policy.highThreshold {
                return (L("state.held"), Theme.mint, "pause.circle.fill")
            }
            return (L("state.safe"), Theme.mint, "checkmark.seal.fill")
        case .warned:
            return (L("state.warned"), Theme.caution, "exclamationmark.triangle.fill")
        case .enforcing:
            return (L("state.enforcing"), Theme.danger, "lock.fill")
        }
    }

    var body: some View {
        let l = label
        Label(l.text, systemImage: l.symbol)
            .font(.system(size: large ? 18 : 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, large ? 14 : 8)
            .padding(.vertical, large ? 8 : 4)
            .background(l.color.opacity(0.18), in: Capsule())
            .foregroundStyle(l.color)
    }
}
