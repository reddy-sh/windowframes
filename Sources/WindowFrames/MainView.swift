import AppKit
import SwiftUI

/// The WindowFrames window, opened from the menu bar icon.
struct MainView: View {
    @ObservedObject var model: AppModel
    let openAccessibilitySettings: () -> Void
    let quit: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !model.isTrusted { permissionBanner }

                section("Layouts") {
                    Text(targetLine)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(WindowAction.allCases, id: \.self) { action in
                            LayoutButton(
                                action: action,
                                shortcut: model.bindings[action],
                                enabled: model.isTrusted && model.targetAppName != nil
                            ) {
                                model.perform(action, bringToFront: true)
                            }
                        }
                    }
                }

                section("Keyboard shortcuts") { shortcutsSection }

                section("General") {
                    Toggle("Open at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    if let note = model.launchAtLoginNote {
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                section("Updates") { updateRow }

                HStack {
                    Spacer()
                    Button("Quit WindowFrames", action: quit)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 560, idealHeight: 720)
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("WindowFrames").font(.title2.bold())
                Text("Version \(model.version)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Accessibility permission needed").font(.headline)
                Text("Turn on WindowFrames in Privacy & Security → Accessibility so it can move other apps' windows.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings", action: openAccessibilitySettings)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Click a shortcut, then press the new keys. Use at least one of ⌃ ⌥ ⌘, or a function key.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Copy from Magnet", action: model.importFromMagnet)
                Button("Reset to Defaults", action: model.restoreDefaults)
            }

            if let note = model.shortcutNote {
                Text(note)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            VStack(spacing: 0) {
                ForEach(Array(WindowAction.groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 { Divider().padding(.vertical, 4) }
                    ForEach(group, id: \.self) { action in
                        ShortcutRow(model: model, action: action)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        }
    }

    @ViewBuilder
    private var updateRow: some View {
        HStack(spacing: 10) {
            Button("Check for Updates", action: model.checkForUpdates)
                .disabled(model.update == .checking)
            switch model.update {
            case .idle:
                EmptyView()
            case .checking:
                ProgressView().controlSize(.small)
            case .upToDate:
                Text("You have the latest version.").foregroundStyle(.secondary)
            case let .available(version, url):
                Text("Version \(version) is available.")
                Button("Download") { NSWorkspace.shared.open(url) }
            case let .failed(message):
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var targetLine: String {
        if let name = model.targetAppName {
            return "Click a layout to arrange the front window of \(name)."
        }
        return "Switch to the app you want to arrange, then come back here."
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }
}

/// One command in the shortcut list: name, recorder button, clear button,
/// and a warning when the shortcut can't work or takes over a common one.
private struct ShortcutRow: View {
    @ObservedObject var model: AppModel
    let action: WindowAction

    var body: some View {
        let shortcut = model.bindings[action]
        let isRecording = model.recording == action

        HStack(spacing: 8) {
            Text(action.title)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let warning = warning(for: shortcut) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(warning)
                    .accessibilityLabel(warning)
            }

            Button {
                isRecording ? model.cancelRecording() : model.startRecording(action)
            } label: {
                Text(isRecording ? "Press keys…" : (shortcut?.display ?? "Record shortcut"))
                    .monospacedDigit()
                    .frame(minWidth: 130)
            }
            .help(isRecording ? "Press the new shortcut, or Esc to cancel" : "Change the shortcut for \(action.title)")
            .accessibilityLabel(isRecording
                ? "Recording shortcut for \(action.title)"
                : "\(action.title) shortcut: \(shortcut?.display ?? "none")")

            Button {
                model.clearShortcut(action)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(shortcut == nil || isRecording)
            .opacity(shortcut == nil ? 0 : 1)
            .help("Remove the shortcut for \(action.title)")
            .accessibilityLabel("Remove the shortcut for \(action.title)")
        }
        .padding(.vertical, 3)
    }

    private func warning(for shortcut: Shortcut?) -> String? {
        guard let shortcut else { return nil }
        if model.unavailable.contains(action) {
            return "Another app already uses \(shortcut.display), so this shortcut doesn't work. Pick another one."
        }
        if let conflict = shortcut.systemConflict {
            return "This takes over \(conflict) in every app."
        }
        return nil
    }
}

/// One layout tile: a preview of the target area, its name and shortcut.
private struct LayoutButton: View {
    let action: WindowAction
    let shortcut: Shortcut?
    let enabled: Bool
    let run: () -> Void

    var body: some View {
        Button(action: run) {
            VStack(spacing: 6) {
                LayoutPreview(action: action)
                    .frame(width: 72, height: 45)
                Text(action.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(shortcut?.display ?? "No shortcut")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .help(shortcut.map { "\(action.title) (\($0.display))" } ?? action.title)
        .accessibilityLabel(action.title)
    }
}

/// Draws the screen outline with the action's target area filled in, using
/// the same geometry the real window move uses. Commands without a fixed
/// area show a symbol instead.
private struct LayoutPreview: View {
    let action: WindowAction

    var body: some View {
        GeometryReader { geo in
            let screen = CGRect(origin: .zero, size: geo.size)
            let window = CGRect(x: 0, y: 0, width: geo.size.width * 0.6, height: geo.size.height * 0.6)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary, lineWidth: 1)
                if let target = action.frame(for: window, in: screen) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor)
                        .frame(width: max(target.width - 4, 1), height: max(target.height - 4, 1))
                        .offset(x: target.minX + 2, y: target.minY + 2)
                } else if let symbol = action.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
