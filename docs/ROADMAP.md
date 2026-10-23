# WindowFrames roadmap

Ideas from other window managers (checked October 2026), and where
WindowFrames could do better. Ordered by value for effort.

## What others do

| App | Notable features |
|---|---|
| [Rectangle](https://rectangleapp.com/comparison) (free) | Halves to sixths, almost maximise, smaller/larger, repeat a shortcut to cycle sizes, drag to edges, Todo mode |
| [Rectangle Pro](https://rectangleapp.com/pro) (paid) | Window throw (hold keys, nudge the cursor), saved workspaces restored by shortcut or when a display connects, stash windows off screen, iCloud sync |
| [Moom](https://manytricks.com/moom/help/whatsnew.html) (paid) | Draw a layout on a grid, saved layouts that can hide other apps, layouts triggered by display changes |
| [Loop](https://github.com/MrKai77/Loop) (free) | Hold a key, a radial menu appears, move the cursor towards the direction |
| [PowerToys FancyZones](https://learn.microsoft.com/windows/powertoys/fancyzones) (Windows) | Draw custom zones per monitor, hold Shift while dragging to drop into a zone |
| [AeroSpace](https://github.com/nikitabobko/AeroSpace) (free) | Automatic i3-style tiling, virtual workspaces, text config |
| [macOS tiling](https://support.apple.com/guide/mac-help/mchlef287e5d/mac) (built in) | Drag to edges, hold Option while dragging, green-button menu, Fill and Arrange |

## Next (small, high value)

1. **Repeat to cycle**: pressing Left Half again goes ½ → ⅔ → ⅓. Fewer
   shortcuts to remember.
2. **Gaps**: space between windows and screen edges (Magnet's padding
   setting).
3. **Drag to edge with a preview**: Magnet and Rectangle both do it; the
   built-in macOS version has fewer areas.
4. **Shortcut conflict check**: warn about clashes with Mission Control
   (⌃1–⌃3 switch desktops) and with other apps, before saving.
5. **Export and import shortcuts** as a JSON file.

## Later (bigger, sets WindowFrames apart)

1. **Leader key**: press one shortcut (for example ⌃⌥Space), then a single
   letter. One global shortcut instead of nineteen, so nothing clashes with
   ⌘Q, ⌘W or ⌘1–⌘9.
2. **Throw**: hold a key, a small overlay appears at the cursor, flick
   towards a layout (Loop's radial menu and Rectangle Pro's throw).
3. **Workspaces**: save where every app's windows are, restore with one
   shortcut, and restore automatically when a display connects or
   disconnects.
4. **App rules**: "Mail always opens on the right third of the second
   display".
5. **Draw your own layout** on a grid, per display, including ultrawide
   splits (Moom, FancyZones).
6. **Command palette**: type "left two" to pick a command.
7. **Multi-step undo** instead of a single Restore.

## Not possible without private APIs

Keeping a window always on top, and moving windows between Spaces, need
private macOS APIs or turning off System Integrity Protection. WindowFrames
uses only public APIs.
