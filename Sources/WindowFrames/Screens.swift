import AppKit

/// Converts between AppKit screen coordinates (origin bottom-left of the
/// primary display, y up) and Accessibility coordinates (origin top-left of
/// the primary display, y down).
enum Screens {
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func toAX(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Usable area, in AX coordinates, of the screen that holds most of `window`.
    static func visibleFrameAX(containing window: CGRect) -> CGRect? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in screens {
            let overlap = toAX(screen.frame).intersection(window)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        if best == nil {
            // Window is off every screen: use the one nearest its centre.
            let centre = CGPoint(x: window.midX, y: window.midY)
            best = screens.min { a, b in
                distance(centre, toAX(a.frame)) < distance(centre, toAX(b.frame))
            }
        }
        return best.map { toAX($0.visibleFrame) }
    }

    private static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
