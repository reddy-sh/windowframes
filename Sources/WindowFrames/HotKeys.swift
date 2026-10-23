import AppKit
import Carbon

/// A global keyboard shortcut: a virtual key code plus Carbon modifier bits.
struct Shortcut: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// Readable form, e.g. "⌃⌥←".
    var display: String {
        KeyNames.modifierSymbols(modifiers) + KeyNames.name(for: keyCode)
    }

    var menuKey: String { KeyNames.menuKey(for: keyCode) }

    var menuModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    /// A common shortcut this one takes over in every app, if any.
    var systemConflict: String? {
        let cmd = UInt32(cmdKey)
        if modifiers == cmd {
            let names: [Int: String] = [
                kVK_ANSI_Q: "Quit", kVK_ANSI_W: "Close window", kVK_ANSI_H: "Hide",
                kVK_ANSI_M: "Minimise", kVK_ANSI_N: "New", kVK_ANSI_T: "New tab",
                kVK_ANSI_C: "Copy", kVK_ANSI_V: "Paste", kVK_ANSI_X: "Cut", kVK_ANSI_Z: "Undo",
                kVK_ANSI_A: "Select all", kVK_ANSI_S: "Save", kVK_ANSI_F: "Find",
                kVK_ANSI_P: "Print", kVK_ANSI_O: "Open", kVK_Tab: "App switcher",
                kVK_Space: "Spotlight", kVK_ANSI_Comma: "Settings",
            ]
            if let name = names[Int(keyCode)] { return "\(display) (\(name))" }
            let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                          kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
            if digits.contains(Int(keyCode)) { return "\(display) (switch tabs)" }
            let arrows = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]
            if arrows.contains(Int(keyCode)) { return "\(display) (move to line or document start/end)" }
        }
        if modifiers == cmd | UInt32(shiftKey), keyCode == UInt32(kVK_ANSI_Z) { return "\(display) (Redo)" }
        return nil
    }
}

/// Registers global hot keys with the Carbon Event Manager. These work
/// without Accessibility or Input Monitoring permission.
final class HotKeyCenter {
    private static let signature: OSType = "WFrm".utf8.reduce(0) { ($0 << 8) | OSType($1) }

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// Returns false if the shortcut is already taken by another app.
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        actions[id] = action
        return true
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == HotKeyCenter.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { center.fire(hotKeyID.id) }
            return noErr
        }, 1, &spec, context, &handlerRef)
    }
}
