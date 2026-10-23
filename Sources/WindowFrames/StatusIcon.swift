import AppKit

/// The menu bar icon: a small monitor with one tall and two stacked panes,
/// matching the app icon. Drawn as a template so it follows light and dark
/// menu bars.
enum StatusIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let screen = NSRect(x: 1.75, y: 4.25, width: 14.5, height: 11)
            let outline = NSBezierPath(roundedRect: screen, xRadius: 2.5, yRadius: 2.5)
            outline.lineWidth = 1.5
            outline.stroke()

            let inner = screen.insetBy(dx: 2.5, dy: 2.5)
            let gap: CGFloat = 1.25
            let half = (inner.width - gap) / 2
            let stack = (inner.height - gap) / 2
            let panes = [
                NSRect(x: inner.minX, y: inner.minY, width: half, height: inner.height),
                NSRect(x: inner.minX + half + gap, y: inner.minY + stack + gap, width: half, height: stack),
                NSRect(x: inner.minX + half + gap, y: inner.minY, width: half, height: stack),
            ]
            for pane in panes {
                NSBezierPath(roundedRect: pane, xRadius: 0.6, yRadius: 0.6).fill()
            }

            NSBezierPath(rect: NSRect(x: 8.25, y: 1.75, width: 1.5, height: 2.5)).fill()
            NSBezierPath(roundedRect: NSRect(x: 5.5, y: 0.75, width: 7, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "WindowFrames"
        return image
    }
}
