import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let hotKeys = HotKeyCenter()
    private let model = AppModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "WindowFrames")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "WindowFrames"
        }

        var unavailable: Set<WindowAction> = []
        for action in WindowAction.allCases {
            guard let shortcut = Shortcut.defaults[action] else { continue }
            let ok = hotKeys.register(shortcut) { [weak self] in self?.perform(action) }
            if !ok { unavailable.insert(action) }
        }
        model.unavailable = unavailable

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // First run, or permission was removed: explain in the window.
        if !AppModel.checkTrusted(prompt: false) {
            showWindow()
        }
    }

    /// Opening the app again from Finder, Spotlight or Launchpad while it is
    /// running brings up the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.unregisterAll()
    }

    // MARK: Window

    @objc private func showWindow() {
        if window == nil {
            let view = MainView(
                model: model,
                openAccessibilitySettings: { [weak self] in self?.openAccessibilitySettings() },
                quit: { NSApp.terminate(nil) }
            )
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "WindowFrames"
            newWindow.isReleasedWhenClosed = false
            newWindow.contentView = NSHostingView(rootView: view)
            newWindow.setFrameAutosaveName("WindowFramesMain")
            if !newWindow.setFrameUsingName("WindowFramesMain") {
                newWindow.center()
            }
            window = newWindow
        }
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        model.refresh()

        menu.addItem(item("Show WindowFrames", #selector(showWindow)))
        menu.addItem(.separator())

        if !model.isTrusted {
            let warning = NSMenuItem(title: "Needs Accessibility permission", action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
            menu.addItem(item("Open Accessibility Settings…", #selector(openAccessibilitySettings)))
            menu.addItem(.separator())
        }

        for (index, group) in WindowAction.groups.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for action in group {
                let entry = item(action.title, #selector(menuAction(_:)))
                entry.representedObject = action.rawValue
                if let shortcut = Shortcut.defaults[action], !model.unavailable.contains(action) {
                    entry.keyEquivalent = shortcut.menuKey
                    entry.keyEquivalentModifierMask = shortcut.menuModifiers
                } else {
                    entry.toolTip = "Shortcut in use by another app"
                }
                menu.addItem(entry)
            }
        }

        menu.addItem(.separator())
        menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(item("About WindowFrames", #selector(showAbout)))
        menu.addItem(item("Quit WindowFrames", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        entry.target = self
        return entry
    }

    @objc private func menuAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let action = WindowAction(rawValue: raw) else { return }
        perform(action)
    }

    @objc private func checkForUpdates() {
        showWindow()
        model.checkForUpdates()
    }

    @objc private func openAccessibilitySettings() {
        // Adds WindowFrames to the Accessibility list, then opens that page.
        _ = AppModel.checkTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func perform(_ action: WindowAction) {
        if !model.perform(action, bringToFront: false) {
            showWindow()
        }
    }
}
