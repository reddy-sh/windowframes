import AppKit
import Carbon

/// A global keyboard shortcut.
struct Shortcut {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    /// Key equivalent shown in the menu.
    let menuKey: String
    let menuModifiers: NSEvent.ModifierFlags

    static func controlOption(_ keyCode: Int, _ menuKey: String) -> Shortcut {
        Shortcut(
            keyCode: UInt32(keyCode),
            carbonModifiers: UInt32(controlKey | optionKey),
            menuKey: menuKey,
            menuModifiers: [.control, .option]
        )
    }

    private static func function(_ key: Int) -> String {
        String(Character(UnicodeScalar(UInt32(key))!))
    }

    /// Default shortcuts: Control + Option + key.
    static let defaults: [WindowAction: Shortcut] = [
        .leftHalf: .controlOption(kVK_LeftArrow, function(NSLeftArrowFunctionKey)),
        .rightHalf: .controlOption(kVK_RightArrow, function(NSRightArrowFunctionKey)),
        .topHalf: .controlOption(kVK_UpArrow, function(NSUpArrowFunctionKey)),
        .bottomHalf: .controlOption(kVK_DownArrow, function(NSDownArrowFunctionKey)),
        .topLeft: .controlOption(kVK_ANSI_U, "u"),
        .topRight: .controlOption(kVK_ANSI_I, "i"),
        .bottomLeft: .controlOption(kVK_ANSI_J, "j"),
        .bottomRight: .controlOption(kVK_ANSI_K, "k"),
        .leftThird: .controlOption(kVK_ANSI_D, "d"),
        .centerThird: .controlOption(kVK_ANSI_F, "f"),
        .rightThird: .controlOption(kVK_ANSI_G, "g"),
        .leftTwoThirds: .controlOption(kVK_ANSI_E, "e"),
        .rightTwoThirds: .controlOption(kVK_ANSI_T, "t"),
        .maximize: .controlOption(kVK_Return, "\r"),
        .center: .controlOption(kVK_ANSI_C, "c"),
    ]
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
            shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
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
