import CoreGraphics

/// A window layout. Geometry is computed in the Accessibility coordinate
/// space: origin at the top-left of the primary display, y grows downwards.
enum WindowAction: String, CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case maximize, center

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
        case .rightTwoThirds: return "Right Two Thirds"
        case .maximize: return "Maximise"
        case .center: return "Centre"
        }
    }

    /// Menu sections, in display order.
    static let groups: [[WindowAction]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds],
        [.maximize, .center],
    ]

    /// Target frame for a window currently at `window` on a screen whose
    /// usable area (menu bar and Dock excluded) is `screen`.
    func frame(for window: CGRect, in screen: CGRect) -> CGRect {
        let s = screen
        let halfW = (s.width / 2).rounded(.down)
        let halfH = (s.height / 2).rounded(.down)
        let thirdW = (s.width / 3).rounded(.down)

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
        case .leftThird:
            return CGRect(x: s.minX, y: s.minY, width: thirdW, height: s.height)
        case .centerThird:
            return CGRect(x: s.minX + thirdW, y: s.minY, width: thirdW, height: s.height)
        case .rightThird:
            return CGRect(x: s.minX + 2 * thirdW, y: s.minY, width: s.width - 2 * thirdW, height: s.height)
        case .leftTwoThirds:
            return CGRect(x: s.minX, y: s.minY, width: 2 * thirdW, height: s.height)
        case .rightTwoThirds:
            return CGRect(x: s.minX + thirdW, y: s.minY, width: s.width - thirdW, height: s.height)
        case .maximize:
            return s
        case .center:
            let w = min(window.width, s.width)
            let h = min(window.height, s.height)
            return CGRect(x: (s.midX - w / 2).rounded(), y: (s.midY - h / 2).rounded(), width: w, height: h)
        }
    }
}
