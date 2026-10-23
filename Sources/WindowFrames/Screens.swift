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
        screen(containing: window).map { toAX($0.visibleFrame) }
    }

    /// The same relative position and size as `window`, on the next
    /// (`step` = 1) or previous (`step` = -1) display, left to right.
    static func frame(_ window: CGRect, movedBy step: Int) -> CGRect? {
        let ordered = NSScreen.screens.sorted { a, b in
            a.frame.minX != b.frame.minX ? a.frame.minX < b.frame.minX : a.frame.maxY > b.frame.maxY
        }
        guard ordered.count > 1,
              let current = screen(containing: window),
              let index = ordered.firstIndex(of: current)
        else { return nil }

        let target = ordered[(index + step + ordered.count) % ordered.count]
        let from = toAX(current.visibleFrame)
        let to = toAX(target.visibleFrame)

        let width = min((window.width / from.width * to.width).rounded(), to.width)
        let height = min((window.height / from.height * to.height).rounded(), to.height)
        var x = (to.minX + (window.minX - from.minX) / from.width * to.width).rounded()
        var y = (to.minY + (window.minY - from.minY) / from.height * to.height).rounded()
        x = min(max(x, to.minX), to.maxX - width)
        y = min(max(y, to.minY), to.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func screen(containing window: CGRect) -> NSScreen? {
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
        if let best { return best }

        // Window is off every screen: use the one nearest its centre.
        let centre = CGPoint(x: window.midX, y: window.midY)
        return screens.min { a, b in
            distance(centre, toAX(a.frame)) < distance(centre, toAX(b.frame))
        }
    }

    private static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
