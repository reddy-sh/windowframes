import AppKit
import SwiftUI

/// Development aid: renders every page of the window to PNG and quits.
/// Run the binary with WF_SNAPSHOT_DIR=/some/folder to use it. Global
/// shortcuts and the menu bar icon are not set up in this mode.
enum Snapshot {
    static var requestedDirectory: URL? {
        ProcessInfo.processInfo.environment["WF_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static func run(model: AppModel, into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]
            for (label, appearance) in appearances {
                for pane in Pane.allCases {
                    capture(model: model, pane: pane, appearance: appearance,
                            to: directory.appendingPathComponent("\(pane.rawValue)-\(label).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }

    private static func capture(model: AppModel, pane: Pane, appearance: NSAppearance.Name, to url: URL) {
        // The offscreen capture skips the window's own background, so draw one.
        let view = MainView(model: model, initialPane: pane, openAccessibilitySettings: {}, quit: {})
            .background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 660),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.titlebarAppearsTransparent = true
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
        window.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        host.layoutSubtreeIfNeeded()

        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
        window.orderOut(nil)
    }
}
