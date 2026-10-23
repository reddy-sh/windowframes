import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let model = AppModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let directory = Snapshot.requestedDirectory {
            model.loadShortcuts(register: false)
            Snapshot.run(model: model, into: directory)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = StatusIcon.make()
            button.toolTip = "WindowFrames"
        }

        model.onNeedsPermission = { [weak self] in self?.showWindow() }
        model.loadShortcuts()

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
        model.unregisterShortcuts()
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
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "WindowFrames"
            newWindow.titlebarAppearsTransparent = true
            newWindow.toolbar = NSToolbar(identifier: "WindowFramesToolbar")
            newWindow.toolbarStyle = .unified
            newWindow.contentMinSize = NSSize(width: 760, height: 540)
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.contentView = NSHostingView(rootView: view)
            newWindow.setFrameAutosaveName("WindowFramesMainV2")
            if !newWindow.setFrameUsingName("WindowFramesMainV2") {
                newWindow.center()
            }
            window = newWindow
        }
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.cancelRecording()
    }

    func windowDidResignKey(_ notification: Notification) {
        model.cancelRecording()
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
            for action in group.actions {
                let entry = item(action.title, #selector(menuAction(_:)))
                entry.representedObject = action.rawValue
                if let shortcut = model.bindings[action], !model.unavailable.contains(action) {
                    entry.keyEquivalent = shortcut.menuKey
                    entry.keyEquivalentModifierMask = shortcut.menuModifiers
                } else if model.bindings[action] != nil {
                    entry.toolTip = "Shortcut in use by another app"
                }
                menu.addItem(entry)
            }
        }

        menu.addItem(.separator())
        menu.addItem(item("Change Shortcuts…", #selector(showWindow)))
        menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(item("About WindowFrames", #selector(showAbout)))
        menu.addItem(item("Quit WindowFrames", #selector(quit)))
    }

    private func item(_ title: String, _ selector: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        entry.target = self
        return entry
    }

    @objc private func menuAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let action = WindowAction(rawValue: raw) else { return }
        if !model.perform(action, bringToFront: false) {
            showWindow()
        }
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
}
