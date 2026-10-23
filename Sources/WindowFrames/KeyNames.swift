import AppKit
import Carbon

/// Human-readable names and menu key equivalents for virtual key codes.
enum KeyNames {
    private static func scalar(_ value: Int) -> String {
        String(Character(UnicodeScalar(UInt32(value))!))
    }

    /// Keys that don't type a character: (display name, menu key equivalent).
    private static let special: [Int: (String, String)] = {
        var table: [Int: (String, String)] = [
            kVK_Return: ("↩", "\r"),
            kVK_ANSI_KeypadEnter: ("⌤", scalar(0x03)),
            kVK_Tab: ("⇥", "\t"),
            kVK_Space: ("Space", " "),
            kVK_Delete: ("⌫", scalar(NSBackspaceCharacter)),
            kVK_ForwardDelete: ("⌦", scalar(NSDeleteFunctionKey)),
            kVK_Escape: ("⎋", scalar(0x1B)),
            kVK_LeftArrow: ("←", scalar(NSLeftArrowFunctionKey)),
            kVK_RightArrow: ("→", scalar(NSRightArrowFunctionKey)),
            kVK_UpArrow: ("↑", scalar(NSUpArrowFunctionKey)),
            kVK_DownArrow: ("↓", scalar(NSDownArrowFunctionKey)),
            kVK_Home: ("↖", scalar(NSHomeFunctionKey)),
            kVK_End: ("↘", scalar(NSEndFunctionKey)),
            kVK_PageUp: ("⇞", scalar(NSPageUpFunctionKey)),
            kVK_PageDown: ("⇟", scalar(NSPageDownFunctionKey)),
        ]
        for (index, code) in functionKeys.enumerated() {
            table[code] = ("F\(index + 1)", scalar(NSF1FunctionKey + index))
        }
        return table
    }()

    /// F1 to F20, in order.
    private static let functionKeys: [Int] = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        functionKeys.contains(Int(keyCode))
    }

    /// Modifier symbols in Apple's standard order: ⌃⌥⇧⌘.
    static func modifierSymbols(_ carbon: UInt32) -> String {
        var s = ""
        if carbon & UInt32(controlKey) != 0 { s += "⌃" }
        if carbon & UInt32(optionKey) != 0 { s += "⌥" }
        if carbon & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbon & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    static func name(for keyCode: UInt32) -> String {
        if let entry = special[Int(keyCode)] { return entry.0 }
        if let typed = translate(keyCode), !typed.isEmpty { return typed.uppercased() }
        return "Key \(keyCode)"
    }

    static func menuKey(for keyCode: UInt32) -> String {
        if let entry = special[Int(keyCode)] { return entry.1 }
        return translate(keyCode)?.lowercased() ?? ""
    }

    /// The character the key types on the current ASCII-capable keyboard
    /// layout, so names follow QWERTY, AZERTY, Dvorak and so on.
    private static func translate(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data

        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length)
        return text.trimmingCharacters(in: .controlCharacters).isEmpty ? nil : text
    }
}
