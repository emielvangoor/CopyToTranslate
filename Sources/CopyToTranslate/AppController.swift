import AppKit
import ClipboardCore
import ServiceManagement
import SwiftUI
import Translation

@MainActor final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    static let spanish = Locale.Language(identifier: "es")
    static let english = Locale.Language(identifier: "en")
    static let demo = "La reunión se ha cambiado al jueves a las diez. ¿Puedes confirmarme si te viene bien?"
    static let dutchDemo = "did is een  test"

    @Published var enabled = UserDefaults.standard.bool(forKey: "enabled")
    @Published var paused = UserDefaults.standard.bool(forKey: "paused")
    @Published var setupMessage = "Download Spanish and English once, then translate entirely on your Mac."
    @Published var preparing = false
    @Published private(set) var dutchEnabled = UserDefaults.standard.bool(forKey: "dutchEnabled")
    @Published private(set) var dutchSetupMessage = "Uses \(DutchProofreader.modelDisplayName) through OpenRouter."
    @Published private(set) var checkingDutch = false
    @Published private(set) var hasOpenRouterKey = false
    @Published private(set) var keyEditorRevision = UUID()
    private var keyRevision = UUID()
    @Published private(set) var dutchShortcutError: String?
    @Published private(set) var selectionAccessAllowed = SelectedTextReader().hasPermission
    private var spanishReady = false
    @Published private(set) var loginItemStatus = SMAppService.mainApp.status
    @Published private(set) var loginItemError: String?
    var launchAtLogin: Bool { loginItemStatus == .enabled || loginItemStatus == .requiresApproval }
    var loginItemNeedsApproval: Bool { loginItemStatus == .requiresApproval }
    private var suspension = SuspensionState()
    private var suspended: Bool { suspension.isSuspended }
    private var statusItem: NSStatusItem!
    private var setupWindow: NSWindow?
    private var generation = UUID()
    private var availabilityTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var readingSelection = false
    private let detector = SpanishDetector()
    private let dutchDetector = DutchDetector()
    private let selectedText = SelectedTextReader()
    private let card = TranslationPanel()
    private lazy var dutchShortcut = GlobalProofreadingShortcut { [weak self] in
        self?.processSelectedText()
    }
    private var statusText = "Setup needed"
    private lazy var clipboard = ClipboardMonitor(pasteboard: .general) { [weak self] text in
        self?.request(text, manual: false)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "CopyToTranslate")
        clipboard.onAccessBlocked = { [weak self] in
            guard let self else { return }
            cancelCurrent()
            statusText = "Clipboard access needed — open Setup"
            setupMessage = "Allow clipboard access for CopyToTranslate in System Settings, then click Enable Translation."
            refreshMenu()
        }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(suspend), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(resumeAfterSleep), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(suspend), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(resumeAfterSleep), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(suspend), name: .init("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(resumeAfterSleep), name: .init("com.apple.screenIsUnlocked"), object: nil)
        refreshMenu()
        if enabled {
            Task { await checkReadiness() }
        } else {
            openSetup()
        }
        updateDutchShortcut()
        if dutchEnabled { Task { await checkDutchSetup() } }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshLoginItemStatus()
        selectionAccessAllowed = selectedText.hasPermission
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSetup()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        dutchShortcut.unregister()
        clipboard.stop()
        cancelCurrent()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func refreshMenu() {
        let menu = NSMenu()
        let heading = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())
        addItem(paused ? "Resume Translation" : "Pause Translation", action: #selector(togglePause), to: menu, enabled: enabled)
        addItem("Translate Clipboard as Spanish", action: #selector(translateClipboard), to: menu, enabled: enabled && !suspended && !preparing)
        addItem("Test Translation", action: #selector(runDemo), to: menu, enabled: enabled && !suspended && !preparing)
        if dutchEnabled {
            addItem("Translate or Correct Selection (§)", action: #selector(processSelectedText), to: menu, enabled: enabled && !suspended && !preparing)
            addItem("Correct Dutch Clipboard", action: #selector(correctDutchClipboard), to: menu, enabled: enabled && !suspended && !preparing)
            addItem("Test Dutch Correction", action: #selector(runDutchDemo), to: menu, enabled: enabled && !suspended && !preparing)
        }
        menu.addItem(.separator())
        addItem("Setup…", action: #selector(openSetup), to: menu)
        addItem("Quit CopyToTranslate", action: #selector(quit), key: "q", to: menu)
        statusItem.menu = menu
        statusItem.button?.toolTip = "CopyToTranslate — \(statusText)"
        statusItem.button?.appearsDisabled = paused || !enabled
    }

    private func addItem(_ title: String, action: Selector, key: String = "", to menu: NSMenu, enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled
        menu.autoenablesItems = false
        menu.addItem(item)
    }

    @objc func openSetup() {
        refreshLoginItemStatus()
        selectionAccessAllowed = selectedText.hasPermission
        Task { await checkDutchSetup() }
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 450),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "CopyToTranslate"
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SetupView(controller: self))
            window.center()
            setupWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === setupWindow {
            keyEditorRevision = UUID()
        }
    }

    private func hideSetup() {
        keyEditorRevision = UUID()
        setupWindow?.orderOut(nil)
    }

    private func refreshLoginItemStatus() {
        let status = SMAppService.mainApp.status
        if status != loginItemStatus { loginItemError = nil }
        loginItemStatus = status
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
            refreshLoginItemStatus()
        } catch {
            refreshLoginItemStatus()
            loginItemError = "Couldn’t change launch at login: \(error.localizedDescription)"
        }
    }

    func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func openSelectionAccessSettings() {
        selectedText.openPermissionSettings()
    }

    func setDutchEnabled(_ value: Bool) {
        dutchEnabled = value
        UserDefaults.standard.set(value, forKey: "dutchEnabled")
        updateDutchShortcut()
        cancelCurrent()
        if value, !enabled, !suspended, !paused {
            // Enabling this feature is an explicit clipboard-access action too.
            _ = clipboard.currentText()
            if clipboard.automaticAccessAllowed {
                enabled = true
                UserDefaults.standard.set(true, forKey: "enabled")
            }
        }
        startIfAllowed()
        if value { Task { await checkDutchSetup() } }
    }

    private func updateDutchShortcut() {
        dutchShortcutError = nil
        if dutchEnabled {
            if dutchShortcut.register() != 0 {
                dutchShortcutError = "The § key is unavailable. Use Correct Dutch Clipboard from the menu, or free the key in another app and turn this switch off and on."
            }
        } else {
            dutchShortcut.unregister()
        }
    }

    func checkDutchSetup() async {
        guard !checkingDutch else { return }
        checkingDutch = true
        let revision = keyRevision
        defer { if revision == keyRevision { checkingDutch = false } }
        do {
            let key = try OpenRouterKeychain().load()
            hasOpenRouterKey = true
            try await DutchProofreader(apiKey: key).checkAvailability()
            guard revision == keyRevision else { return }
            dutchSetupMessage = "Key checked. Dutch proofreading uses \(DutchProofreader.modelDisplayName)."
        } catch {
            guard revision == keyRevision else { return }
            if case DutchProofreadingError.missingKey = error { hasOpenRouterKey = false }
            dutchSetupMessage = (error as? DutchProofreadingError)?.errorDescription ?? "Couldn’t check OpenRouter. Try again."
        }
    }

    func saveOpenRouterKey(_ key: String) -> Bool {
        cancelCurrent()
        do {
            try OpenRouterKeychain().save(key)
            keyRevision = UUID()
            checkingDutch = false
            hasOpenRouterKey = true
            dutchSetupMessage = "Key saved in macOS Keychain."
            Task { await checkDutchSetup() }
            return true
        } catch {
            dutchSetupMessage = (error as? DutchProofreadingError)?.errorDescription ?? "Couldn’t save the API key."
            return false
        }
    }

    func removeOpenRouterKey() {
        cancelCurrent()
        do {
            try OpenRouterKeychain().remove()
            keyRevision = UUID()
            checkingDutch = false
            hasOpenRouterKey = false
            dutchSetupMessage = "API key removed. Add a key to use Dutch proofreading."
        } catch {
            dutchSetupMessage = DutchProofreadingError.keychainUnavailable.errorDescription ?? "Couldn’t remove the API key."
        }
    }

    func prepare(using session: sending TranslationSession) async {
        preparing = true
        clipboard.stop()
        cancelCurrent()
        statusText = "Preparing languages…"
        refreshMenu()
        defer {
            preparing = false
            // Cancelling or failing Spanish setup must not leave Dutch tools stopped.
            if enabled && (spanishReady || dutchEnabled) { startIfAllowed() }
            else { refreshMenu() }
        }
        do {
            let availability = await LanguageAvailability().status(from: Self.spanish, to: Self.english)
            guard availability != .unsupported else {
                setupMessage = "Spanish-to-English translation is not available on this Mac."
                statusText = "Translation unavailable"
                return
            }
            setupMessage = "Preparing Spanish and English…"
            try await session.prepareTranslation()
            guard !Task.isCancelled else { return }
            guard await LanguageAvailability().status(from: Self.spanish, to: Self.english) == .installed else {
                setupMessage = "Language downloads are still in progress. Wait for them to finish, then enable translation again."
                statusText = "Language downloads needed — open Setup"
                refreshMenu()
                return
            }
            spanishReady = true
            guard !suspended, !paused else {
                setupMessage = "Languages are ready. Resume translation from the menu bar, or enable it after unlocking your Mac."
                statusText = paused ? "Paused" : "Setup needed"
                return
            }
            // This user-initiated read can present macOS's clipboard permission UI.
            // Its contents are deliberately discarded; monitoring starts from a fresh baseline.
            _ = clipboard.currentText()
            guard clipboard.automaticAccessAllowed else {
                setupMessage = "Allow clipboard access for CopyToTranslate in System Settings, then try again."
                statusText = "Clipboard access needed"
                refreshMenu()
                return
            }
            enabled = true
            UserDefaults.standard.set(true, forKey: "enabled")
            // Preparing models must not override a newer Pause action.
            setupMessage = paused
                ? "Languages are ready. Translation is paused; resume it from the menu bar."
                : "Ready. Copy Spanish text in any app, or try the example below."
            preparing = false
            startIfAllowed()
        } catch {
            guard !Task.isCancelled else { return }
            setupMessage = "Couldn’t prepare translation. Check your connection and try again."
            statusText = "Setup needed"
            refreshMenu()
        }
    }

    private func checkReadiness() async {
        let availability = await LanguageAvailability().status(from: Self.spanish, to: Self.english)
        guard enabled, !suspended, !preparing else { return }
        spanishReady = availability == .installed
        guard spanishReady || dutchEnabled else {
            clipboard.stop()
            statusText = "Language downloads needed — open Setup"
            setupMessage = "Prepare Spanish and English to resume on-device translation."
            refreshMenu()
            return
        }
        startIfAllowed()
    }

    private func startIfAllowed() {
        clipboard.stop()
        if !enabled {
            statusText = "Setup needed"
        } else if suspended {
            statusText = "Suspended"
        } else if paused {
            statusText = "Paused"
        } else if preparing {
            statusText = "Preparing languages…"
        } else if !spanishReady && !dutchEnabled {
            statusText = "Language downloads needed — open Setup"
        } else if !clipboard.automaticAccessAllowed {
            statusText = "Clipboard access needed — open Setup"
        } else {
            clipboard.start()
            statusText = dutchEnabled
                ? (spanishReady ? "Spanish → English · § Translate or correct" : "§ Translate or correct")
                : "Spanish → English · On-device"
        }
        refreshMenu()
    }

    @objc private func togglePause() {
        paused.toggle()
        UserDefaults.standard.set(paused, forKey: "paused")
        cancelCurrent()
        if paused { startIfAllowed() } else { Task { await checkReadiness() } }
    }

    @objc private func translateClipboard() { request(clipboard.currentTextForManualAction(), manual: true) }

    @objc func runDemo() {
        hideSetup()
        request(Self.demo, manual: true)
    }

    @objc func runDutchDemo() {
        hideSetup()
        requestDutch(Self.dutchDemo)
    }

    @objc private func correctDutchClipboard() {
        guard enabled, !suspended, !preparing, dutchEnabled else { return }
        hideSetup()
        requestDutch(clipboard.currentTextForManualAction())
    }

    @objc private func processSelectedText() {
        guard !readingSelection else { return }
        guard enabled, !suspended, !preparing, dutchEnabled else { return }
        cancelCurrent()
        // Consume older clipboard changes without reading or altering their contents.
        // A pending poll must not immediately dismiss the new selection's card.
        clipboard.acknowledgeCurrentChange()
        let requestID = generation
        readingSelection = true
        selectionTask = Task { [weak self] in
            guard let self else { return }
            defer { readingSelection = false }
            do {
                let selected = try await selectedText.readIncludingMessages(clipboard: clipboard)
                guard !Task.isCancelled, generation == requestID else { return }
                selectionTask = nil
                let source = try ShortcutInput.read(selection: { selected }, clipboard: {
                    clipboard.currentTextForManualAction()
                })
                hideSetup()
                switch ShortcutClassifier().classify(source) {
                case .spanish(let text): request(text, manual: true)
                case .dutch(let text): requestDutch(text)
                case nil:
                    showShortcutMessage("Select Spanish text to translate, or a Dutch sentence to correct, then press §. Code and unsupported text are skipped. With nothing selected, § uses your clipboard.")
                }
            } catch {
                guard !Task.isCancelled, generation == requestID else { return }
                selectionTask = nil
                hideSetup()
                showShortcutMessage((error as? SelectedTextError)?.errorDescription ?? "Couldn’t read the selected text. Try again.")
            }
        }
    }

    private func requestDutch(_ text: String?) {
        cancelCurrent()
        guard enabled, !suspended, !preparing, dutchEnabled else { return }
        guard let source = dutchDetector.candidate(text) else {
            showShortcutMessage("Select a Dutch sentence or email, then press §. Names, code and very short fragments are skipped. With nothing selected, § uses your clipboard.")
            return
        }
        showCard(source: source, kind: .dutchProofreading)
    }

    private func showShortcutMessage(_ message: String) {
        card.show(source: "", kind: .dutchProofreading, error: message,
                  copy: { _ in false }, setup: { [weak self] in self?.openSetup() })
    }

    private func showCard(source: String, kind: CardKind) {
        card.show(source: source, kind: kind, copy: { [weak self] result in
            self?.clipboard.copyTranslation(result) ?? false
        }, setup: { [weak self] in self?.openSetup() })
    }

    private func request(_ text: String?, manual: Bool) {
        cancelCurrent()
        guard enabled, !suspended, !preparing, manual || !paused else { return }
        guard let source = detector.candidate(text, manual: manual) else {
            if manual {
                statusText = "No eligible text — copy a short passage"
                refreshMenu()
            }
            return
        }
        let requestID = generation
        availabilityTask = Task { [weak self] in
            let availability = await LanguageAvailability().status(from: Self.spanish, to: Self.english)
            guard let self, generation == requestID, !Task.isCancelled else { return }
            guard availability == .installed else {
                spanishReady = false
                if !dutchEnabled { clipboard.stop() }
                statusText = "Language downloads needed — open Setup"
                setupMessage = "Prepare Spanish and English to resume on-device translation."
                if manual { showShortcutMessage("Spanish and English language downloads are needed. Open Setup and choose Prepare Languages, then try again.") }
                refreshMenu()
                return
            }
            spanishReady = true
            showCard(source: source, kind: .spanishTranslation)
        }
    }

    private func cancelCurrent() {
        generation = UUID()
        selectionTask?.cancel()
        selectionTask = nil
        availabilityTask?.cancel()
        availabilityTask = nil
        card.hide()
    }

    @objc private func suspend(_ notification: Notification) {
        switch notification.name {
        case NSWorkspace.willSleepNotification: suspension.suspend(for: .sleep)
        case NSWorkspace.sessionDidResignActiveNotification: suspension.suspend(for: .inactiveSession)
        default: suspension.suspend(for: .screenLock)
        }
        clipboard.stop()
        cancelCurrent()
        hideSetup()
        statusText = "Suspended"
        refreshMenu()
    }

    @objc private func resumeAfterSleep(_ notification: Notification) {
        switch notification.name {
        case NSWorkspace.didWakeNotification: suspension.resume(from: .sleep)
        case NSWorkspace.sessionDidBecomeActiveNotification: suspension.resume(from: .inactiveSession)
        default: suspension.resume(from: .screenLock)
        }
        if !suspended { Task { await checkReadiness() } }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
