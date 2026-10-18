import AppKit
import SwiftUI

/// Adaptive "ink" colors that keep icons/badges readable in both appearances.
/// The system orange/green are tuned for filled shapes, not small text/icons on
/// light surfaces, so the light variants use darker tones (WCAG-friendly).
extension Color {
    static var warningInk: Color { adaptive(light: (0.52, 0.30, 0.02), dark: (1.0, 0.76, 0.36)) }
    static var successInk: Color { adaptive(light: (0.05, 0.38, 0.22), dark: (0.45, 0.87, 0.62)) }
    static var errorInk: Color { adaptive(light: (0.64, 0.12, 0.09), dark: (1.0, 0.56, 0.52)) }
    static var secondaryInk: Color { adaptive(light: (0.37, 0.37, 0.37), dark: (0.66, 0.66, 0.66)) }

    private static func adaptive(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let value = isDark ? dark : light
            return NSColor(srgbRed: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
}
