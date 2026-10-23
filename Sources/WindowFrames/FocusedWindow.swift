import AppKit
import ApplicationServices

/// The focused window of the frontmost app, read and moved through the
/// Accessibility API.
struct FocusedWindow {
    let element: AXUIElement

    static func current(pid: pid_t) -> FocusedWindow? {
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }

        let app = AXUIElementCreateApplication(pid)
        // An app that has stopped responding would otherwise block
        // WindowFrames for the 6 s system default.
        AXUIElementSetMessagingTimeout(app, 1.0)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = value,
              CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return nil }
        return FocusedWindow(element: window as! AXUIElement)
    }

    var frame: CGRect? {
        guard let positionValue = axValue(kAXPositionAttribute),
              let sizeValue = axValue(kAXSizeAttribute)
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// Moves and resizes the window. Position is set before and after the
    /// size, because some apps clamp the size to the screen the window is on
    /// at the moment the size changes.
    @discardableResult
    func setFrame(_ frame: CGRect) -> Bool {
        var origin = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin),
              let dimensions = AXValueCreate(.cgSize, &size)
        else { return false }
        let a = set(kAXPositionAttribute, position)
        let b = set(kAXSizeAttribute, dimensions)
        let c = set(kAXPositionAttribute, position)
        return a || b || c
    }

    private func axValue(_ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }
        return (raw as! AXValue)
    }

    private func set(_ attribute: String, _ value: AXValue) -> Bool {
        AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    }
}
