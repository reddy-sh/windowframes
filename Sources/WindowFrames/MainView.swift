import AppKit
import SwiftUI

/// Pages in the sidebar.
enum Pane: String, CaseIterable, Identifiable {
    case layouts, shortcuts, general, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layouts: return "Layouts"
        case .shortcuts: return "Shortcuts"
        case .general: return "General"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .layouts: return "rectangle.split.2x2"
        case .shortcuts: return "keyboard"
        case .general: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

/// The WindowFrames window, opened from the menu bar icon.
struct MainView: View {
    @ObservedObject var model: AppModel
    let openAccessibilitySettings: () -> Void
    let quit: () -> Void

    @State private var pane: Pane?

    init(model: AppModel, initialPane: Pane = .layouts,
         openAccessibilitySettings: @escaping () -> Void, quit: @escaping () -> Void) {
        self.model = model
        self.openAccessibilitySettings = openAccessibilitySettings
        self.quit = quit
        _pane = State(initialValue: initialPane)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                ForEach(Pane.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .badge(item == .shortcuts ? model.warningCount : 0)
                        .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .safeAreaInset(edge: .bottom) { sidebarFooter }
        } detail: {
            detail
                .navigationTitle((pane ?? .layouts).title)
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    @ViewBuilder
    private var detail: some View {
        switch pane ?? .layouts {
        case .layouts:
            LayoutsPane(model: model, openAccessibilitySettings: openAccessibilitySettings)
        case .shortcuts:
            ShortcutsPane(model: model)
        case .general:
            GeneralPane(model: model, openAccessibilitySettings: openAccessibilitySettings)
        case .about:
            AboutPane(model: model)
        }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.isTrusted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(model.isTrusted ? "Ready" : "Needs permission")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit", action: quit)
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: Layouts

private struct LayoutsPane: View {
    @ObservedObject var model: AppModel
    let openAccessibilitySettings: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 132, maximum: 170), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !model.isTrusted {
                    PermissionBanner(action: openAccessibilitySettings)
                }
                targetBar

                ForEach(WindowAction.groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                            ForEach(group.actions, id: \.self) { action in
                                LayoutTile(
                                    action: action,
                                    shortcut: model.bindings[action],
                                    enabled: model.isTrusted && model.targetAppName != nil
                                ) {
                                    model.perform(action, bringToFront: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var targetBar: some View {
        HStack(spacing: 10) {
            if let icon = model.targetApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            if let name = model.targetAppName {
                Text("Click a layout to arrange the front window of ") + Text(name).bold() + Text(".")
            } else {
                Text("Switch to the app you want to arrange, then come back here.")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

// MARK: Shortcuts

private struct ShortcutsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Button("Copy from Magnet", action: model.importFromMagnet)
                    Button("Reset to Defaults", action: model.restoreDefaults)
                    Spacer()
                }
                if let note = model.shortcutNote {
                    Label(note, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } footer: {
                Text("Click a shortcut and press the new keys. Use at least one of ⌃ ⌥ ⌘, or a function key. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(WindowAction.groups) { group in
                Section(group.title) {
                    ForEach(group.actions, id: \.self) { action in
                        ShortcutRow(model: model, action: action)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRow: View {
    @ObservedObject var model: AppModel
    let action: WindowAction

    var body: some View {
        let warning = model.warning(for: action)
        HStack(spacing: 12) {
            ScreenPreview(action: action)
                .frame(width: 34, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                if let warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            ShortcutRecorder(
                name: action.title,
                shortcut: model.bindings[action],
                isRecording: model.recording == action,
                onTap: {
                    model.recording == action ? model.cancelRecording() : model.startRecording(action)
                },
                onClear: { model.clearShortcut(action) }
            )
        }
        .padding(.vertical, 2)
    }
}

// MARK: General

private struct GeneralPane: View {
    @ObservedObject var model: AppModel
    let openAccessibilitySettings: () -> Void

    var body: some View {
        Form {
            Section("Permission") {
                HStack(spacing: 12) {
                    Image(systemName: model.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(model.isTrusted ? Color.green : Color.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                        Text(model.isTrusted
                             ? "Allowed. WindowFrames can move and resize windows."
                             : "Needed to move other apps' windows.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.isTrusted {
                        Button("Open Settings", action: openAccessibilitySettings)
                    }
                }
            }

            Section("Startup") {
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let note = model.launchAtLoginNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Menu bar") {
                Text("Every command is in the WindowFrames menu in the menu bar. Closing this window keeps WindowFrames running.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: About

private struct AboutPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 120, height: 120)
                .accessibilityHidden(true)
            Text("WindowFrames")
                .font(.system(size: 28, weight: .semibold))
            Text("Version \(model.version)")
                .foregroundStyle(.secondary)
            Text("Snap windows into halves, quarters and thirds from the keyboard or the menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            HStack(spacing: 10) {
                Button("Check for Updates", action: model.checkForUpdates)
                    .disabled(model.update == .checking)
                Button("View on GitHub") {
                    if let url = URL(string: "https://github.com/\(AppModel.repository)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .controlSize(.large)
            .padding(.top, 8)

            UpdateStatus(state: model.update)
                .frame(minHeight: 22)

            Spacer()
            Text("Free and open source under the MIT licence.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
