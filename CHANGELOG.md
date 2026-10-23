# Changelog

All notable changes to WindowFrames are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Release notes for each GitHub release now come from this changelog.
- Releases fail if the tag doesn't match the `VERSION` file.

## [0.4.0] - 2026-10-23

### Added

- App icon, shown in Finder, Spotlight and About, and a matching menu bar icon.
- Sidebar window with Layouts, Shortcuts, General and About pages.
- Accessibility status on the General page, with a button to fix it.
- Snapshot mode (`WF_SNAPSHOT_DIR`) that renders every page to PNG for review.

### Changed

- Layout cards are grouped by type, with live previews and hover highlights.
- Shortcuts are shown as keycaps. Warnings explain clashes in plain words, and
  the sidebar badge counts them.

## [0.3.0] - 2026-10-23

### Added

- Change any shortcut: click it and press the new keys. Remove one, or reset
  all to the defaults.
- Copy shortcuts from Magnet. This happens by itself on first launch when
  Magnet is set up.
- Centre Two Thirds, Next Display, Previous Display and Restore commands.
- Roadmap of ideas from other window managers in `docs/ROADMAP.md`.

### Changed

- Thirds split the height on portrait screens.

### Fixed

- The published `.sha256` file names the zip without a folder, so
  `shasum -c` works next to the download.

## [0.2.0] - 2026-10-23

### Added

- WindowFrames window, opened from the menu bar: click a layout to arrange
  the app you were using.
- Open at login switch.
- Check for Updates, which asks GitHub only when you click it.

### Fixed

- A frozen app can no longer hold up WindowFrames for more than 1 second.

## [0.1.0] - 2026-10-22

### Added

- Menu bar app that snaps the front window into halves, quarters, thirds and
  two thirds, maximises it or centres it.
- Control + Option keyboard shortcuts and a menu bar menu.
- Works across several displays and leaves room for the menu bar and Dock.

[Unreleased]: https://github.com/reddy-sh/windowframes/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/reddy-sh/windowframes/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/reddy-sh/windowframes/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/reddy-sh/windowframes/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/reddy-sh/windowframes/releases/tag/v0.1.0
