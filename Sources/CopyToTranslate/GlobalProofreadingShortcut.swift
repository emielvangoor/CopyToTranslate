import Carbon

/// Reserves the ISO section key globally without reading other apps' keyboard events.
@MainActor final class GlobalProofreadingShortcut {
    private static let signature: OSType = 0x43545444 // CTTD
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isPressed = false
    private let onPress: () -> Void

    init(onPress: @escaping () -> Void) { self.onPress = onPress }

    func register() -> OSStatus {
        if hotKey != nil { return noErr }
        var events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let shortcut = Unmanaged<GlobalProofreadingShortcut>.fromOpaque(context).takeUnretainedValue()
                var identifier = EventHotKeyID()
                let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                               EventParamType(typeEventHotKeyID), nil,
                                               MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard status == noErr, identifier.signature == GlobalProofreadingShortcut.signature, identifier.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    shortcut.isPressed = false
                } else if !shortcut.isPressed {
                    shortcut.isPressed = true
                    shortcut.onPress()
                }
                return noErr
            }
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        guard handlerStatus == noErr else { return handlerStatus }
        let status = RegisterEventHotKey(UInt32(kVK_ISO_Section), 0,
                                         EventHotKeyID(signature: Self.signature, id: 1),
                                         GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { unregister() }
        return status
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
        isPressed = false
    }
}
