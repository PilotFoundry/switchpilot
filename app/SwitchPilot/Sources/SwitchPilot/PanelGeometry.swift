import AppKit

/// Pure panel placement geometry. Keeping this independent of the controller
/// makes left/right-edge magnet alignment and multi-display clamping testable.
enum PanelGeometry {
    static func frame(
        anchor: NSRect,
        visible: NSRect,
        size: NSSize,
        gap: CGFloat = 4,
        edgeGap: CGFloat = 4
    ) -> NSRect {
        var x: CGFloat
        if anchor.midX < visible.midX {
            x = anchor.minX - edgeGap
        } else {
            x = anchor.maxX - size.width + edgeGap
        }
        x = min(max(x, visible.minX + edgeGap), visible.maxX - size.width - edgeGap)
        let y = anchor.minY - gap - size.height
        return NSRect(
            x: x,
            y: max(y, visible.minY + 8),
            width: size.width,
            height: size.height
        )
    }

    static func regressionProbe() -> Bool {
        let size = NSSize(width: 380, height: 600)
        let primary = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let secondary = NSRect(x: -1920, y: -200, width: 1920, height: 1080)
        let cases: [(NSRect, NSRect, NSRect)] = [
            // Right-half anchor: panel trailing edge follows the status item.
            (NSRect(x: 1200, y: 860, width: 80, height: 24), primary,
             NSRect(x: 904, y: 256, width: 380, height: 600)),
            // Left-half anchor: panel leading edge follows the status item.
            (NSRect(x: 100, y: 860, width: 80, height: 24), primary,
             NSRect(x: 96, y: 256, width: 380, height: 600)),
            // Clamp at the left screen edge.
            (NSRect(x: 5, y: 860, width: 20, height: 24), primary,
             NSRect(x: 4, y: 256, width: 380, height: 600)),
            // Clamp at the right screen edge.
            (NSRect(x: 1430, y: 860, width: 10, height: 24), primary,
             NSRect(x: 1056, y: 256, width: 380, height: 600)),
            // Secondary display with negative origin.
            (NSRect(x: -1800, y: 760, width: 80, height: 24), secondary,
             NSRect(x: -1804, y: 156, width: 380, height: 600)),
            // Bottom clamp keeps the panel above the visible-frame floor.
            (NSRect(x: 100, y: 20, width: 80, height: 24), primary,
             NSRect(x: 96, y: 8, width: 380, height: 600)),
        ]
        return cases.allSatisfy { anchor, visible, expected in
            frame(anchor: anchor, visible: visible, size: size) == expected
        }
    }
}
