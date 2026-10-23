import AppKit
import SwiftUI

/// A shortcut drawn as separate keycaps: ⌃ ⌥ R.
struct KeyCaps: View {
    enum Size { case small, regular }

    let shortcut: Shortcut?
    var size: Size = .regular

    var body: some View {
        if let shortcut {
            HStack(spacing: size == .small ? 2 : 3) {
                ForEach(Array(shortcut.parts.enumerated()), id: \.offset) { _, part in
                    Text(part)
                        .font(.system(size: size == .small ? 10 : 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, size == .small ? 3 : 5)
                        .frame(minWidth: size == .small ? 16 : 22, minHeight: size == .small ? 16 : 21)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.16))
                        )
                        .shadow(color: .black.opacity(0.10), radius: 0, x: 0, y: 1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(shortcut.display)
        } else {
            Text("No shortcut")
                .font(.system(size: size == .small ? 10 : 12))
                .foregroundStyle(.tertiary)
        }
    }
}

/// A tiny monitor with the command's target area filled in, drawn with the
/// same geometry the real window move uses.
struct ScreenPreview: View {
    let action: WindowAction
    var highlighted = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 40
            let inset: CGFloat = compact ? 2.5 : 4
            let bar: CGFloat = compact ? 0 : max(geo.size.height * 0.07, 3)
            let screen = CGRect(
                x: inset,
                y: inset + (bar > 0 ? bar + 2 : 0),
                width: geo.size.width - inset * 2,
                height: geo.size.height - inset * 2 - (bar > 0 ? bar + 2 : 0)
            )
            let window = CGRect(x: screen.minX, y: screen.minY, width: screen.width * 0.55, height: screen.height * 0.6)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: compact ? 4 : 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                RoundedRectangle(cornerRadius: compact ? 4 : 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(highlighted ? 0.35 : 0.22), lineWidth: 1)
                if bar > 0 {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: geo.size.width - inset * 2, height: bar)
                        .offset(x: inset, y: inset)
                }
                if let target = action.frame(for: window, in: screen) {
                    RoundedRectangle(cornerRadius: compact ? 1.5 : 3, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: max(target.width - 2, 1), height: max(target.height - 2, 1))
                        .offset(x: target.minX + 1, y: target.minY + 1)
                        .shadow(color: Color.accentColor.opacity(highlighted ? 0.45 : 0), radius: 5)
                } else if let symbol = action.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: geo.size.height * 0.34, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A clickable layout card.
struct LayoutTile: View {
    let action: WindowAction
    let shortcut: Shortcut?
    let enabled: Bool
    let run: () -> Void

    @State private var hovering = false

    var body: some View {
        let active = hovering && enabled
        Button(action: run) {
            VStack(spacing: 10) {
                ScreenPreview(action: action, highlighted: active)
                    .frame(width: 100, height: 64)
                VStack(spacing: 5) {
                    Text(action.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    KeyCaps(shortcut: shortcut, size: .small)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(active ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(shortcut.map { "\(action.title) (\($0.display))" } ?? action.title)
        .accessibilityLabel(action.title)
        .accessibilityHint(shortcut.map { "Shortcut \($0.display)" } ?? "")
    }
}

/// The shortcut field: shows keycaps, records on click, clears with ⓧ.
struct ShortcutRecorder: View {
    let name: String
    let shortcut: Shortcut?
    let isRecording: Bool
    let onTap: () -> Void
    let onClear: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTap) {
                Group {
                    if isRecording {
                        Text("Type shortcut…")
                            .font(.callout)
                            .foregroundStyle(Color.accentColor)
                    } else if let shortcut {
                        KeyCaps(shortcut: shortcut)
                    } else {
                        Text("Record Shortcut")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 136, minHeight: 28)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isRecording ? Color.accentColor.opacity(0.12) : Color.primary.opacity(hovering ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isRecording ? 1.5 : 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(isRecording ? "Press the new shortcut, or Esc to cancel" : "Click to change the shortcut")
            .accessibilityLabel(isRecording
                ? "Recording shortcut for \(name)"
                : "\(name) shortcut, \(shortcut?.display ?? "none")")

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(shortcut == nil || isRecording ? 0 : 1)
            .disabled(shortcut == nil || isRecording)
            .help("Remove shortcut")
            .accessibilityLabel("Remove shortcut for \(name)")
        }
    }
}

/// Shown until Accessibility permission is granted.
struct PermissionBanner: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.orange))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Allow WindowFrames to move windows").font(.headline)
                Text("Turn it on in System Settings → Privacy & Security → Accessibility.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button("Open Settings", action: action)
                .controlSize(.large)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.orange.opacity(0.35)))
    }
}

/// The result line under Check for Updates.
struct UpdateStatus: View {
    let state: AppModel.UpdateState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("You have the latest version.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case let .available(version, url):
            HStack(spacing: 8) {
                Label("Version \(version) is available.", systemImage: "arrow.down.circle.fill")
                Button("Download") { NSWorkspace.shared.open(url) }
            }
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
