import AppKit
import ApplicationServices
import Carbon
import ServiceManagement

/// Shared state for the menu bar menu and the WindowFrames window.
final class AppModel: ObservableObject {
    enum UpdateState: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed(String)
    }

    /// GitHub repository that publishes releases.
    static let repository = "reddy-sh/windowframes"

    @Published private(set) var isTrusted = false
    @Published private(set) var targetAppName: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginNote: String?
    @Published private(set) var update: UpdateState = .idle

    @Published private(set) var bindings: [WindowAction: Shortcut] = [:]
    /// Shortcuts another app already owns, so they couldn't be registered.
    @Published private(set) var unavailable: Set<WindowAction> = []
    @Published private(set) var recording: WindowAction?
    @Published private(set) var shortcutNote: String?

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    /// Called when a command can't run because Accessibility is off.
    var onNeedsPermission: (() -> Void)?

    private let hotKeys = HotKeyCenter()
    private let history = RestoreHistory()
    /// The last app other than WindowFrames that was in front. Layouts chosen
    /// in the WindowFrames window apply to this app's front window.
    private var lastOtherApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var timer: Timer?

    init() {
        let workspace = NSWorkspace.shared
        if let front = workspace.frontmostApplication, front != NSRunningApplication.current {
            lastOtherApp = front
        }
        activationObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app != NSRunningApplication.current else { return }
            self?.lastOtherApp = app
            self?.refresh()
        }
        // Picks up the Accessibility switch being turned on in System Settings.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    deinit {
        timer?.invalidate()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    var targetApp: NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication, front != NSRunningApplication.current {
            return front
        }
        guard let last = lastOtherApp, !last.isTerminated else { return nil }
        return last
    }

    func refresh() {
        let trusted = Self.checkTrusted(prompt: false)
        if trusted != isTrusted { isTrusted = trusted }

        let name = targetApp?.localizedName
        if name != targetAppName { targetAppName = name }

        let status = SMAppService.mainApp.status
        let enabled = status == .enabled || status == .requiresApproval
        if enabled != launchAtLogin { launchAtLogin = enabled }
        if status == .requiresApproval {
            launchAtLoginNote = "Allow WindowFrames in System Settings → General → Login Items."
        } else if launchAtLoginNote?.hasPrefix("Allow") == true {
            launchAtLoginNote = nil
        }
    }

    // MARK: Shortcuts

    /// Loads saved shortcuts. On first run, copies Magnet's shortcuts when
    /// Magnet has been set up on this Mac, otherwise uses the defaults.
    func loadShortcuts(register: Bool = true) {
        if ShortcutStore.hasSaved {
            bindings = ShortcutStore.load()
        } else if let magnet = ShortcutStore.magnetShortcuts() {
            bindings = magnet
            ShortcutStore.save(magnet)
            shortcutNote = "Copied \(magnet.count) shortcuts from Magnet."
        } else {
            bindings = ShortcutStore.builtIn
        }
        if register { registerShortcuts() }
    }

    /// Why the shortcut for `action` needs attention, if it does.
    func warning(for action: WindowAction) -> String? {
        guard let shortcut = bindings[action] else { return nil }
        if unavailable.contains(action) {
            return "Another app already uses \(shortcut.display). Pick a different shortcut."
        }
        if let conflict = shortcut.systemConflict {
            return "Replaces \(conflict) in every app."
        }
        return nil
    }

    var warningCount: Int {
        WindowAction.allCases.filter { warning(for: $0) != nil }.count
    }

    func importFromMagnet() {
        guard let magnet = ShortcutStore.magnetShortcuts() else {
            shortcutNote = "Magnet's settings weren't found on this Mac."
            return
        }
        setBindings(magnet)
        shortcutNote = "Copied \(magnet.count) shortcuts from Magnet."
    }

    func restoreDefaults() {
        setBindings(ShortcutStore.builtIn)
        shortcutNote = "Shortcuts reset to the WindowFrames defaults."
    }

    func clearShortcut(_ action: WindowAction) {
        var updated = bindings
        updated[action] = nil
        setBindings(updated)
        shortcutNote = "\(action.title) has no shortcut now."
    }

    /// Waits for the next key press in the WindowFrames window and assigns
    /// it to `action`. Global shortcuts are paused meanwhile, so pressing an
    /// existing shortcut records it instead of moving a window.
    func startRecording(_ action: WindowAction) {
        stopRecording()
        recording = action
        shortcutNote = "Press the new shortcut for \(action.title). Esc cancels."
        hotKeys.unregisterAll()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording != nil else { return event }
            self.handleRecorded(event)
            return nil
        }
    }

    func cancelRecording() {
        guard recording != nil else { return }
        stopRecording()
        shortcutNote = nil
        registerShortcuts()
    }

    private func handleRecorded(_ event: NSEvent) {
        guard let action = recording else { return }
        let keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])

        if keyCode == UInt32(kVK_Escape), flags.isEmpty {
            cancelRecording()
            return
        }
        if flags.subtracting(.shift).isEmpty, !KeyNames.isFunctionKey(keyCode) {
            shortcutNote = "Use at least one of ⌃ ⌥ ⌘ with the key, or a function key. Esc cancels."
            NSSound.beep()
            return
        }

        let shortcut = Shortcut(keyCode: keyCode, modifiers: Shortcut.carbonModifiers(from: flags))
        var updated = bindings
        var note = "\(action.title): \(shortcut.display)."
        if let previous = updated.first(where: { $0.key != action && $0.value == shortcut })?.key {
            updated[previous] = nil
            note += " Removed it from \(previous.title)."
        }
        if let conflict = shortcut.systemConflict {
            note += " This replaces \(conflict) in every app."
        }
        updated[action] = shortcut
        stopRecording()
        setBindings(updated)
        shortcutNote = note
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        recording = nil
    }

    private func setBindings(_ updated: [WindowAction: Shortcut]) {
        bindings = updated
        ShortcutStore.save(updated)
        registerShortcuts()
    }

    private func registerShortcuts() {
        hotKeys.unregisterAll()
        var failed: Set<WindowAction> = []
        for action in WindowAction.allCases {
            guard let shortcut = bindings[action] else { continue }
            let ok = hotKeys.register(shortcut) { [weak self] in
                guard let self else { return }
                if !self.perform(action, bringToFront: false) { self.onNeedsPermission?() }
            }
            if !ok { failed.insert(action) }
        }
        unavailable = failed
    }

    func unregisterShortcuts() {
        hotKeys.unregisterAll()
    }

    // MARK: Window actions

    /// Runs `action` on the target app's front window. Returns false when
    /// Accessibility permission is missing, so the caller can explain why.
    @discardableResult
    func perform(_ action: WindowAction, bringToFront: Bool) -> Bool {
        guard Self.checkTrusted(prompt: false) else {
            refresh()
            return false
        }
        guard let app = targetApp,
              let window = FocusedWindow.current(pid: app.processIdentifier),
              let current = window.frame
        else {
            NSSound.beep()
            return true
        }

        let target: CGRect?
        switch action {
        case .restore:
            target = history.takeOriginal(window.element)
        case .nextDisplay:
            target = Screens.frame(current, movedBy: 1)
        case .previousDisplay:
            target = Screens.frame(current, movedBy: -1)
        default:
            target = Screens.visibleFrameAX(containing: current).flatMap { action.frame(for: current, in: $0) }
        }
        guard let target else {
            NSSound.beep()
            return true
        }

        if action != .restore { history.willMove(window.element, from: current) }
        if bringToFront { app.activate(options: []) }
        if window.setFrame(target) {
            if action != .restore { history.didMove(window.element, to: window.frame ?? target) }
        } else {
            NSSound.beep()
        }
        return true
    }

    static func checkTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    // MARK: Open at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginNote = nil
        } catch {
            launchAtLoginNote = "Couldn't change this: \(error.localizedDescription) Install WindowFrames in Applications and try again."
        }
        refresh()
    }

    // MARK: Updates

    /// Asks GitHub for the latest release. Runs only when the user asks.
    func checkForUpdates() {
        guard update != .checking,
              let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")
        else { return }
        update = .checking

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let installed = version

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let state: UpdateState
            if let error {
                state = .failed("Couldn't reach GitHub: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                state = .failed("No releases have been published yet.")
            } else if let data,
                      let release = try? JSONDecoder().decode(Release.self, from: data),
                      let page = URL(string: release.html_url),
                      page.scheme == "https", page.host == "github.com" {
                let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                state = Self.isVersion(latest, newerThan: installed)
                    ? .available(version: latest, url: page)
                    : .upToDate
            } else {
                state = .failed("GitHub sent an unexpected reply. Try again later.")
            }
            DispatchQueue.main.async { self?.update = state }
        }.resume()
    }

    static func isVersion(_ candidate: String, newerThan installed: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = installed.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }
}
