# WindowFrames

A small macOS menu bar app that snaps the front window into halves, quarters
and thirds with keyboard shortcuts. Free and open source (MIT).

Needs macOS 13 Ventura or later, on Apple silicon or Intel.

## Shortcuts

All shortcuts are **Control + Option** (⌃⌥) plus a key. The same actions are
in the menu bar menu (the grid icon).

| Action | Key |
|---|---|
| Left / right half | ← / → |
| Top / bottom half | ↑ / ↓ |
| Top left / top right quarter | U / I |
| Bottom left / bottom right quarter | J / K |
| Left / centre / right third | D / F / G |
| Left / right two thirds | E / T |
| Maximise | Return |
| Centre | C |

Each action uses the screen the window is mostly on, and leaves room for the
menu bar and the Dock. If another app already owns a shortcut, that action
still works from the menu.

## Install

### Option 1: download (no developer tools needed)

1. Open the [latest release](../../releases/latest) and download
   `WindowFrames-<version>.zip`.
2. Double-click the zip, then drag **WindowFrames.app** into **Applications**.
3. The app isn't notarised by Apple yet, so macOS blocks the first launch.
   Either run this once in Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/WindowFrames.app
   ```
   or open the app, then go to **System Settings → Privacy & Security** and
   click **Open Anyway**.
4. Open WindowFrames. A grid icon appears in the menu bar.
5. When asked, allow it under **System Settings → Privacy & Security →
   Accessibility**. WindowFrames needs this to move other apps' windows.

### Option 2: build from source

You need the Xcode Command Line Tools (`xcode-select --install`) or Xcode.

```bash
git clone https://github.com/reddy-sh/windowframes.git
cd windowframes
./scripts/install.sh
```

The script builds the app, copies it into `/Applications` (or
`~/Applications`) and opens it. Then allow Accessibility as in step 5.

## Update

- **Download:** quit WindowFrames, replace the app in Applications with the
  new one, and allow Accessibility again if shortcuts stop working.
- **Source:** `git pull && ./scripts/install.sh`.

Each new build has a new signature, so macOS treats it as a new app. The
install script clears the old Accessibility entry so the prompt comes back.
If you replaced the app by hand and shortcuts do nothing, remove WindowFrames
from the Accessibility list with the − button and add it again.

## Start at login

**System Settings → General → Login Items → Open at Login → +**, then choose
WindowFrames.

## Uninstall

```bash
./scripts/uninstall.sh
```

Or quit it from the menu, delete it from Applications, and remove it from the
Accessibility list.

## Privacy

WindowFrames has no network code and collects nothing. It reads and sets the
position and size of the focused window, and nothing else.

## Build commands

| Command | Result |
|---|---|
| `./scripts/build-app.sh` | `build/WindowFrames.app` for this Mac |
| `ARCHS=universal ./scripts/build-app.sh` | Apple silicon + Intel app (needs Xcode) |
| `./scripts/package.sh` | `build/WindowFrames-<version>.zip` plus a SHA-256 file |
| `swift run` | Run without an app bundle (Accessibility is then granted to your terminal) |

## Releases

Pushing a tag such as `v0.1.0` runs `.github/workflows/build.yml`. It builds a
universal app on GitHub's macOS runner and attaches the zip to a GitHub
release. Change the version in `VERSION` first.

Release builds are signed ad hoc. To remove the Gatekeeper step for users,
sign with a Developer ID (`SIGN_IDENTITY="Developer ID Application: …"`) and
notarise with `xcrun notarytool`. That needs a paid Apple Developer account.

## Licence

MIT. WindowFrames is an independent project, written from Apple's public
APIs. It isn't affiliated with any other window manager.
