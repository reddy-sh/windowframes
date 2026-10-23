import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let hotKeys = HotKeyCenter()
    private var unavailable: Set<WindowAction> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "WindowFrames")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "WindowFrames"
        }

        for action in WindowAction.allCases {
            guard let shortcut = Shortcut.defaults[action] else { continue }
            let ok = hotKeys.register(shortcut) { [weak self] in self?.perform(action) }
            if !ok { unavailable.insert(action) }
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if !Self.isTrusted(prompt: false) {
            _ = Self.isTrusted(prompt: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.unregisterAll()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !Self.isTrusted(prompt: false) {
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
                if let shortcut = Shortcut.defaults[action], !unavailable.contains(action) {
                    entry.keyEquivalent = shortcut.menuKey
                    entry.keyEquivalentModifierMask = shortcut.menuModifiers
                } else {
                    entry.toolTip = "Shortcut in use by another app"
                }
                menu.addItem(entry)
            }
        }

        menu.addItem(.separator())
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

    @objc private func openAccessibilitySettings() {
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

    // MARK: Window actions

    private func perform(_ action: WindowAction) {
        guard Self.isTrusted(prompt: false) else {
            _ = Self.isTrusted(prompt: true)
            return
        }
        guard let window = FocusedWindow.current(),
              let current = window.frame,
              let screen = Screens.visibleFrameAX(containing: current)
        else {
            NSSound.beep()
            return
        }
        if !window.setFrame(action.frame(for: current, in: screen)) {
            NSSound.beep()
        }
    }

    private static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}
