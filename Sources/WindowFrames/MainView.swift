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
            VStack(alignment: .leading, spacing: 22) {
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
                                shortcut: model.unavailable.contains(action) ? nil : Shortcut.defaults[action],
                                enabled: model.isTrusted && model.targetAppName != nil
                            ) {
                                model.perform(action, bringToFront: true)
                            }
                        }
                    }
                }

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
        .frame(minWidth: 480, idealWidth: 520, minHeight: 540, idealHeight: 640)
    }

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
/// the same geometry the real window move uses.
private struct LayoutPreview: View {
    let action: WindowAction

    var body: some View {
        GeometryReader { geo in
            let screen = CGRect(origin: .zero, size: geo.size)
            let window = CGRect(x: 0, y: 0, width: geo.size.width * 0.6, height: geo.size.height * 0.6)
            let target = action.frame(for: window, in: screen)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary, lineWidth: 1)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor)
                    .frame(width: max(target.width - 4, 1), height: max(target.height - 4, 1))
                    .offset(x: target.minX + 2, y: target.minY + 2)
            }
        }
        .accessibilityHidden(true)
    }
}
