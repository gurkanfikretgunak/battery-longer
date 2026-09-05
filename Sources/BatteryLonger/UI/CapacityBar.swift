import SwiftUI

/// mAh capacity strip shown under the stats row.
///
/// Track  = design capacity (what the pack held when new)
/// Light  = what a full charge holds today (`AppleRawMaxCapacity`)
/// Solid  = charge stored right now (`AppleRawCurrentCapacity`)
/// Grey tail after the tick = capacity lost to ageing.
struct CapacityBar: View {
    let snapshot: BatterySnapshot
    @ObservedObject private var l10n = Localization.shared

    var body: some View {
        if snapshot.hasCapacityData,
           let current = snapshot.currentCapacityMAh,
           let max = snapshot.maxCapacityMAh,
           let design = snapshot.designCapacityMAh {
            let maxFrac = Swift.min(1, Double(max) / Double(design))
            let curFrac = Swift.min(maxFrac, Double(current) / Double(design))
            let lost = Swift.max(0, design - max)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.batteryblock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mint)
                    Text(L("capacity.title"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(L("capacity.value", Self.format(current), Self.format(max)))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        // Design capacity track
                        Capsule().fill(Color.primary.opacity(0.10))
                        // Today's full-charge capacity
                        Capsule()
                            .fill(Theme.mint.opacity(0.30))
                            .frame(width: Swift.max(4, w * maxFrac))
                        // Charge stored now
                        Capsule()
                            .fill(Theme.mint)
                            .frame(width: Swift.max(4, w * curFrac))
                        // Tick at today's maximum
                        if maxFrac < 0.995 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.55))
                                .frame(width: 1.5, height: 12)
                                .offset(x: w * maxFrac - 0.75)
                        }
                    }
                }
                .frame(height: 8)

                HStack(spacing: 0) {
                    Text(L("capacity.design", Self.format(design)))
                    Spacer()
                    if lost > 0 {
                        Text(L("capacity.lost", Self.format(lost)))
                            .foregroundStyle(Theme.caution)
                    } else {
                        Text(L("capacity.likeNew"))
                            .foregroundStyle(Theme.mint)
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }
            .help(L("capacity.help"))
        }
    }

    /// Grouped integer in the app's active UI language (e.g. "4,563" / "4.563" / "4 563").
    static func format(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Localization.shared.locale
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
