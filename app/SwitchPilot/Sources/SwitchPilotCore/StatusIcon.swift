import AppKit

/// Template menu bar mark: a compact "S" monogram (SwitchPilot), matching the
/// app icon and deliberately not a generic switch/toggle glyph. Drawn in code
/// so it stays crisp at 1x/2x and follows the system template tint.
public enum StatusIcon {
    public static func make(size: CGFloat = 18, microphoneMuted: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            let margin = rect.width * 0.16
            let inner = rect.insetBy(dx: margin, dy: margin)
            let width = inner.width
            let height = inner.height
            let path = NSBezierPath()
            path.move(to: NSPoint(x: inner.maxX - width * 0.12, y: inner.maxY - height * 0.18))
            path.curve(
                to: NSPoint(x: inner.minX + width * 0.22, y: inner.midY + height * 0.16),
                controlPoint1: NSPoint(x: inner.minX + width * 0.30, y: inner.maxY + height * 0.02),
                controlPoint2: NSPoint(x: inner.minX + width * 0.02, y: inner.midY + height * 0.30))
            path.curve(
                to: NSPoint(x: inner.maxX - width * 0.12, y: inner.minY + height * 0.18),
                controlPoint1: NSPoint(x: inner.maxX - width * 0.02, y: inner.midY - height * 0.30),
                controlPoint2: NSPoint(x: inner.minX + width * 0.30, y: inner.minY - height * 0.02))
            path.lineWidth = max(1.8, inner.height * 0.18)
            path.lineCapStyle = .round
            if microphoneMuted {
                NSColor.black.withAlphaComponent(0.35).setStroke()
            }
            path.stroke()
            if microphoneMuted {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: size * 0.16, y: size * 0.84))
                slash.line(to: NSPoint(x: size * 0.84, y: size * 0.16))
                slash.lineWidth = max(1.6, size * 0.11)
                slash.lineCapStyle = .round
                NSColor.black.setStroke()
                slash.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = microphoneMuted ? "SwitchPilot，麦克风已静音" : "SwitchPilot"
        return image
    }
}
