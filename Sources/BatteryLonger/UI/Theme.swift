import SwiftUI

enum Theme {
    /// Mint accent matching the sketch artwork.
    static let mint = Color(red: 0.42, green: 0.80, blue: 0.64)
    static let mintSoft = Color(red: 0.42, green: 0.80, blue: 0.64).opacity(0.22)
    static let danger = Color(red: 0.95, green: 0.35, blue: 0.32)
    static let caution = Color(red: 0.98, green: 0.66, blue: 0.22)
    static let ink = Color.primary.opacity(0.85)
    static let paper = Color(nsColor: .windowBackgroundColor)

    static func zoneColor(for level: Int) -> Color {
        if level < Policy.lowThreshold { return danger }
        if level > Policy.highThreshold { return caution }
        return mint
    }
}
