import AppKit
@preconcurrency import ApplicationServices

enum SelectedTextError: LocalizedError {
    case permissionRequired, unavailable, secureField

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "Allow Accessibility access in Setup to use selected text with §. You can also copy text and use a clipboard command from the menu."
        case .unavailable:
            "This app doesn’t expose its selected text. Copy the passage, then use a clipboard command from the menu."
        case .secureField:
            "Password fields can’t be processed. Select text in a regular text field."
        }
    }
}

enum ShortcutInput {
    /// Only a confirmed empty selection may use the clipboard. Access failures must not.
    static func read(selection: () throws -> String?, clipboard: () -> String?) throws -> String? {
        if let selected = try selection() { return selected }
        return clipboard()
    }
}

@MainActor struct SelectedTextReader {
    var hasPermission: Bool { AXIsProcessTrusted() }

    func openPermissionSettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Reads only the foreground selection, on an explicit shortcut or menu action.
    /// It never sends Copy keystrokes or reads the field's entire value.
    func read() throws -> String? {
        guard hasPermission else { throw SelectedTextError.permissionRequired }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              pid != ProcessInfo.processInfo.processIdentifier else { throw SelectedTextError.unavailable }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.5)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            throw SelectedTextError.unavailable
        }
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(element, 0.5)
        var subrole: CFTypeRef?
        let subroleStatus = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        guard subroleStatus == .success || subroleStatus == .attributeUnsupported || subroleStatus == .noValue else {
            throw SelectedTextError.unavailable
        }
        guard subrole as? String != kAXSecureTextFieldSubrole as String else { throw SelectedTextError.secureField }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            throw SelectedTextError.unavailable
        }
        return text.isEmpty ? nil : text
    }
}
