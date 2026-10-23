import CoreGraphics

/// A window command. Geometry is computed in the Accessibility coordinate
/// space: origin at the top-left of the primary display, y grows downwards.
enum WindowAction: String, CaseIterable, Codable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, centerTwoThirds, rightTwoThirds
    case nextDisplay, previousDisplay
    case maximize, center, restore

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .leftThird: return "Left Third"
        case .centerThird: return "Centre Third"
        case .rightThird: return "Right Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .centerTwoThirds: return "Centre Two Thirds"
        case .rightTwoThirds: return "Right Two Thirds"
        case .nextDisplay: return "Next Display"
        case .previousDisplay: return "Previous Display"
        case .maximize: return "Maximise"
        case .center: return "Centre"
        case .restore: return "Restore"
        }
    }

    /// Menu and settings sections, in display order.
    static let groups: [[WindowAction]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.leftThird, .centerThird, .rightThird],
        [.leftTwoThirds, .centerTwoThirds, .rightTwoThirds],
        [.nextDisplay, .previousDisplay],
        [.maximize, .center, .restore],
    ]

    /// SF Symbol for commands that have no fixed target area.
    var symbol: String? {
        switch self {
        case .nextDisplay: return "arrow.right.to.line"
        case .previousDisplay: return "arrow.left.to.line"
        case .restore: return "arrow.uturn.backward"
        default: return nil
        }
    }

    /// Target frame for a window currently at `window` on a screen whose
    /// usable area (menu bar and Dock excluded) is `screen`. Returns nil for
    /// commands that depend on more than the screen (displays, restore).
    ///
    /// On a portrait screen, thirds and two-thirds split the height instead
    /// of the width, so they stay usable.
    func frame(for window: CGRect, in screen: CGRect) -> CGRect? {
        let s = screen
        let halfW = (s.width / 2).rounded(.down)
        let halfH = (s.height / 2).rounded(.down)
        let portrait = s.height > s.width

        switch self {
        case .leftHalf:
            return CGRect(x: s.minX, y: s.minY, width: halfW, height: s.height)
        case .rightHalf:
            return CGRect(x: s.minX + halfW, y: s.minY, width: s.width - halfW, height: s.height)
        case .topHalf:
            return CGRect(x: s.minX, y: s.minY, width: s.width, height: halfH)
        case .bottomHalf:
            return CGRect(x: s.minX, y: s.minY + halfH, width: s.width, height: s.height - halfH)
        case .topLeft:
            return CGRect(x: s.minX, y: s.minY, width: halfW, height: halfH)
        case .topRight:
            return CGRect(x: s.minX + halfW, y: s.minY, width: s.width - halfW, height: halfH)
        case .bottomLeft:
            return CGRect(x: s.minX, y: s.minY + halfH, width: halfW, height: s.height - halfH)
        case .bottomRight:
            return CGRect(x: s.minX + halfW, y: s.minY + halfH, width: s.width - halfW, height: s.height - halfH)
        case .leftThird, .centerThird, .rightThird,
             .leftTwoThirds, .centerTwoThirds, .rightTwoThirds:
            return thirds(in: s, portrait: portrait)
        case .maximize:
            return s
        case .center:
            let w = min(window.width, s.width)
            let h = min(window.height, s.height)
            return CGRect(x: (s.midX - w / 2).rounded(), y: (s.midY - h / 2).rounded(), width: w, height: h)
        case .nextDisplay, .previousDisplay, .restore:
            return nil
        }
    }

    /// Splits the screen into thirds along its long side. `start` and
    /// `length` are in sixths of that side.
    private func thirds(in s: CGRect, portrait: Bool) -> CGRect {
        let (start, length): (CGFloat, CGFloat)
        switch self {
        case .leftThird: (start, length) = (0, 2)
        case .centerThird: (start, length) = (2, 2)
        case .rightThird: (start, length) = (4, 2)
        case .leftTwoThirds: (start, length) = (0, 4)
        case .centerTwoThirds: (start, length) = (1, 4)
        default: (start, length) = (2, 4) // rightTwoThirds
        }
        let side = portrait ? s.height : s.width
        let a = (side * start / 6).rounded(.down)
        let b = start + length >= 6 ? side : (side * (start + length) / 6).rounded(.down)
        if portrait {
            return CGRect(x: s.minX, y: s.minY + a, width: s.width, height: b - a)
        }
        return CGRect(x: s.minX + a, y: s.minY, width: b - a, height: s.height)
    }
}
