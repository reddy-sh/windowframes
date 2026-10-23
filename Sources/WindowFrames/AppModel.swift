import AppKit
import ApplicationServices
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
    @Published var unavailable: Set<WindowAction> = []

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    /// The last app other than WindowFrames that was in front. Layouts chosen
    /// in the WindowFrames window apply to this app's front window.
    private var lastOtherApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
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

    // MARK: Window actions

    /// Arranges the target app's front window. Returns false when
    /// Accessibility permission is missing, so the caller can explain why.
    @discardableResult
    func perform(_ action: WindowAction, bringToFront: Bool) -> Bool {
        guard Self.checkTrusted(prompt: false) else {
            refresh()
            return false
        }
        guard let app = targetApp,
              let window = FocusedWindow.current(pid: app.processIdentifier),
              let current = window.frame,
              let screen = Screens.visibleFrameAX(containing: current)
        else {
            NSSound.beep()
            return true
        }
        if bringToFront {
            app.activate(options: [])
        }
        if !window.setFrame(action.frame(for: current, in: screen)) {
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
