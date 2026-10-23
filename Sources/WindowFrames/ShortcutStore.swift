import Carbon
import Foundation

/// Saved shortcuts, the built-in defaults, and import from Magnet.
enum ShortcutStore {
    private static let key = "shortcuts.v1"

    private struct Saved: Codable {
        var bindings: [String: Shortcut]
    }

    private static func ctrlOpt(_ keyCode: Int) -> Shortcut {
        Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(controlKey | optionKey))
    }

    /// Defaults for new users: Control + Option + key, so no app's own
    /// shortcuts are taken over.
    static let builtIn: [WindowAction: Shortcut] = [
        .leftHalf: ctrlOpt(kVK_LeftArrow),
        .rightHalf: ctrlOpt(kVK_RightArrow),
        .topHalf: ctrlOpt(kVK_UpArrow),
        .bottomHalf: ctrlOpt(kVK_DownArrow),
        .topLeft: ctrlOpt(kVK_ANSI_U),
        .topRight: ctrlOpt(kVK_ANSI_I),
        .bottomLeft: ctrlOpt(kVK_ANSI_J),
        .bottomRight: ctrlOpt(kVK_ANSI_K),
        .leftThird: ctrlOpt(kVK_ANSI_D),
        .centerThird: ctrlOpt(kVK_ANSI_F),
        .rightThird: ctrlOpt(kVK_ANSI_G),
        .leftTwoThirds: ctrlOpt(kVK_ANSI_E),
        .centerTwoThirds: ctrlOpt(kVK_ANSI_R),
        .rightTwoThirds: ctrlOpt(kVK_ANSI_T),
        .nextDisplay: Shortcut(keyCode: UInt32(kVK_RightArrow), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        .previousDisplay: Shortcut(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        .maximize: ctrlOpt(kVK_Return),
        .center: ctrlOpt(kVK_ANSI_C),
        .restore: ctrlOpt(kVK_Delete),
    ]

    static var hasSaved: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    static func load() -> [WindowAction: Shortcut] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return builtIn }
        var result: [WindowAction: Shortcut] = [:]
        for (raw, shortcut) in saved.bindings {
            if let action = WindowAction(rawValue: raw) { result[action] = shortcut }
        }
        return result
    }

    static func save(_ bindings: [WindowAction: Shortcut]) {
        let saved = Saved(bindings: Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) }))
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: Magnet import

    private static let magnetDomain = "com.crowdcafe.windowmagnet" as CFString

    /// Magnet's own command names and legacy keys, mapped to WindowFrames.
    private static let magnetNames: [String: WindowAction] = [
        "left": .leftHalf, "right": .rightHalf, "up": .topHalf, "down": .bottomHalf,
        "topLeft": .topLeft, "topRight": .topRight, "bottomLeft": .bottomLeft, "bottomRight": .bottomRight,
        "leftThird": .leftThird, "centerThird": .centerThird, "rightThird": .rightThird,
        "leftTwoThirds": .leftTwoThirds, "centerTwoThirds": .centerTwoThirds, "rightTwoThirds": .rightTwoThirds,
        "nextDisplay": .nextDisplay, "previousDisplay": .previousDisplay,
        "maximize": .maximize, "center": .center, "restore": .restore,
    ]

    private static let magnetLegacyKeys: [String: WindowAction] = [
        "expandWindowWestComboKey": .leftHalf, "expandWindowEastComboKey": .rightHalf,
        "expandWindowNorthComboKey": .topHalf, "expandWindowSouthComboKey": .bottomHalf,
        "expandWindowNorthWestComboKey": .topLeft, "expandWindowNorthEastComboKey": .topRight,
        "expandWindowSouthWestComboKey": .bottomLeft, "expandWindowSouthEastComboKey": .bottomRight,
        "expandWindowLeftThirdComboKey": .leftThird, "expandWindowCenterThirdComboKey": .centerThird,
        "expandWindowRightThirdComboKey": .rightThird,
        "expandWindowLeftTwoThirdsComboKey": .leftTwoThirds, "expandWindowRightTwoThirdsComboKey": .rightTwoThirds,
        "moveWindowToNextDisplay": .nextDisplay, "moveWindowToPreviousDisplay": .previousDisplay,
        "maximizeWindowComboKey": .maximize, "centerWindowComboKey": .center, "restoreWindowComboKey": .restore,
    ]

    /// Keyboard shortcuts from Magnet's landscape-screen commands, if Magnet
    /// has been set up on this Mac. Reads only the command list.
    static func magnetShortcuts() -> [WindowAction: Shortcut]? {
        guard let value = CFPreferencesCopyAppValue("horizontalCommands" as CFString, magnetDomain) else {
            return nil
        }
        let data: Data
        if let d = value as? Data {
            data = d
        } else if let s = value as? String, let d = s.data(using: .utf8) {
            data = d
        } else {
            return nil
        }
        guard let commands = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        var result: [WindowAction: Shortcut] = [:]
        for command in commands {
            guard let action = magnetAction(command),
                  let keyboard = command["keyboardShortcut"] as? [String: Any],
                  keyboard["enabled"] as? Bool == true,
                  let shortcut = keyboard["shortcut"] as? [String: Any],
                  let keyCode = (shortcut["carbonKeyCode"] as? NSNumber)?.uint32Value,
                  let modifiers = (shortcut["carbonModifiers"] as? NSNumber)?.uint32Value
            else { continue }
            result[action] = Shortcut(keyCode: keyCode, modifiers: modifiers)
        }
        return result.isEmpty ? nil : result
    }

    private static func magnetAction(_ command: [String: Any]) -> WindowAction? {
        let prefix = "command:default.name."
        if let name = command["name"] as? String, name.hasPrefix(prefix),
           let action = magnetNames[String(name.dropFirst(prefix.count))] {
            return action
        }
        // A command the user renamed keeps its legacy key.
        if let legacy = command["legacyKey"] as? String {
            return magnetLegacyKeys[legacy]
        }
        return nil
    }
}
