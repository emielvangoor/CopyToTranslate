import AppKit
@preconcurrency import ApplicationServices
import ClipboardCore

/// WhatsApp keeps message highlights separate from its focused draft field.
@MainActor struct WhatsAppSelectionCapture {
    nonisolated static func isCopyOnlyMenu(_ identifiers: [String]) -> Bool {
        identifiers.count == 1 && identifiers[0].filter(\.isLetter).lowercased() == "copy"
    }

    nonisolated static func matchesMessage(_ selection: String, descriptions: [String]) -> Bool {
        !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            descriptions.contains { $0.contains(selection) }
    }

    /// nil is returned only for a positively identified composer.
    func read(pid: pid_t, clipboard: ClipboardMonitor) async throws -> String? {
        func active() -> Bool {
            AXIsProcessTrusted() && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        }
        guard active(), let location = CGEvent(source: nil)?.location else { throw SelectedTextError.whatsAppSelection }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.1)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(application, Float(location.x), Float(location.y), &hit) == .success,
              let hit else { throw SelectedTextError.whatsAppSelection }
        let deadline = ContinuousClock.now + .seconds(2)
        guard let message = try messageAncestor(hit, deadline: deadline) else { return nil }
        let descriptions = [string(message, kAXDescriptionAttribute), string(message, kAXValueAttribute)].compactMap { $0 }
        guard !descriptions.isEmpty else { throw SelectedTextError.whatsAppSelection }
        // Some versions expose selected text directly on the message, even though
        // the focused composer reports an empty selection.
        for element in [hit, message] {
            if let selected = string(element, kAXSelectedTextAttribute),
               Self.matchesMessage(selected, descriptions: descriptions), active() {
                try Task.checkCancellation()
                return selected
            }
        }
        try Task.checkCancellation()
        guard findContextMenu(application, deadline: deadline) == nil,
              let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: location, mouseButton: .right),
              let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: location, mouseButton: .right),
              active() else { throw SelectedTextError.whatsAppSelection }
        down.postToPid(pid)
        up.postToPid(pid)
        var copied = false
        do {
            repeat {
                try Task.checkCancellation()
                guard active() else { throw CancellationError() }
                if let menu = findContextMenu(application, deadline: deadline) {
                    let items = children(menu)
                    let identifiers = items.map { string($0, "AXIdentifier") ?? "" }
                    guard Self.isCopyOnlyMenu(identifiers), let item = items.first,
                          attribute(item, kAXEnabledAttribute) as? Bool == true else { throw SelectedTextError.whatsAppSelection }
                    do {
                        return try await clipboard.captureSelectionCopy(copy: {
                            AXUIElementSetMessagingTimeout(item, 0.1)
                            guard active(), AXUIElementPerformAction(item, kAXPressAction as CFString) == .success else { return false }
                            copied = true
                            return true
                        }, isSourceActive: active, matchesSource: {
                            Self.matchesMessage($0, descriptions: descriptions)
                        })
                    } catch is CancellationError { throw CancellationError() }
                    catch { throw SelectedTextError.whatsAppSelection }
                }
                try await Task.sleep(for: .milliseconds(25))
            } while ContinuousClock.now < deadline
            throw SelectedTextError.whatsAppSelection
        } catch {
            if !copied { await closePendingMenu(application, isSourceActive: active) }
            throw error
        }
    }

    private func closePendingMenu(_ application: AXUIElement, isSourceActive: () -> Bool) async {
        let deadline = ContinuousClock.now + .milliseconds(350)
        repeat {
            guard isSourceActive() else { return }
            if let menu = findContextMenu(application, deadline: deadline, allowCancelled: true) {
                AXUIElementSetMessagingTimeout(menu, 0.1)
                AXUIElementPerformAction(menu, kAXCancelAction as CFString)
                return
            }
            // Cancellation must not skip waiting for the already-posted click.
            await Task.detached { try? await Task.sleep(for: .milliseconds(20)) }.value
        } while ContinuousClock.now < deadline
    }

    private func messageAncestor(_ element: AXUIElement, deadline: ContinuousClock.Instant) throws -> AXUIElement? {
        var current: AXUIElement? = element
        for _ in 0..<16 {
            try Task.checkCancellation()
            guard .now < deadline, let element = current else { throw SelectedTextError.whatsAppSelection }
            let identifier = string(element, "AXIdentifier")
            if identifier == "WAMessageBubbleTableViewCell" { return element }
            if identifier == "ChatBar_ComposerTextView" { return nil }
            guard let parent = attribute(element, kAXParentAttribute),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { throw SelectedTextError.whatsAppSelection }
            current = unsafeDowncast(parent, to: AXUIElement.self)
        }
        throw SelectedTextError.whatsAppSelection
    }

    private func findContextMenu(_ application: AXUIElement, deadline: ContinuousClock.Instant,
                                 allowCancelled: Bool = false) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(application, 0)]
        var index = 0
        while index < queue.count, index < 180, .now < deadline, allowCancelled || !Task.isCancelled {
            let (element, depth) = queue[index]
            index += 1
            let role = string(element, kAXRoleAttribute)
            if role == kAXMenuRole { return element }
            if role == kAXMenuBarRole || depth >= 8 || .now >= deadline { continue }
            queue.append(contentsOf: children(element).prefix(max(0, 180 - queue.count)).map { ($0, depth + 1) })
        }
        return nil
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        AXUIElementSetMessagingTimeout(element, 0.1)
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private func string(_ element: AXUIElement, _ name: String) -> String? { attribute(element, name) as? String }
    private func children(_ element: AXUIElement) -> [AXUIElement] { attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
}
