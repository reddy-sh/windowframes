import ApplicationServices
import CoreGraphics

/// Remembers each window's frame from before WindowFrames first moved it,
/// so Restore can put it back.
final class RestoreHistory {
    private struct Entry {
        let element: AXUIElement
        var original: CGRect
        var lastSet: CGRect
    }

    private var entries: [Entry] = []
    private let limit = 100

    /// Call before moving a window. If the user moved or resized it by hand
    /// since WindowFrames last placed it, that hand-placed frame becomes the
    /// new restore point.
    func willMove(_ element: AXUIElement, from current: CGRect) {
        if let i = index(of: element) {
            if !Self.close(entries[i].lastSet, current) {
                entries[i].original = current
            }
        } else {
            entries.append(Entry(element: element, original: current, lastSet: current))
            if entries.count > limit { entries.removeFirst() }
        }
    }

    func didMove(_ element: AXUIElement, to frame: CGRect) {
        if let i = index(of: element) { entries[i].lastSet = frame }
    }

    /// The saved frame, removed from the history.
    func takeOriginal(_ element: AXUIElement) -> CGRect? {
        guard let i = index(of: element) else { return nil }
        return entries.remove(at: i).original
    }

    private func index(of element: AXUIElement) -> Int? {
        entries.firstIndex { CFEqual($0.element, element) }
    }

    private static func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2
            && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }
}
