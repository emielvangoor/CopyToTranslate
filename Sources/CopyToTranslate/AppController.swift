import AppKit
import ClipboardCore
import ServiceManagement
import SwiftUI
import Translation

@MainActor final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    static let spanish = Locale.Language(identifier: "es")
    static let english = Locale.Language(identifier: "en")
    static let demo = "La reunión se ha cambiado al jueves a las diez. ¿Puedes confirmarme si te viene bien?"

    @Published var enabled = UserDefaults.standard.bool(forKey: "enabled")
    @Published var paused = UserDefaults.standard.bool(forKey: "paused")
    @Published var setupMessage = "Download Spanish and English once, then translate entirely on your Mac."
    @Published var preparing = false
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
    private let detector = SpanishDetector()
    private let card = TranslationPanel()
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshLoginItemStatus()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSetup()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
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
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 450),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "CopyToTranslate"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SetupView(controller: self))
            window.center()
            setupWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
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

    func prepare(using session: sending TranslationSession) async {
        preparing = true
        clipboard.stop()
        cancelCurrent()
        statusText = "Preparing languages…"
        refreshMenu()
        defer { preparing = false; refreshMenu() }
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
        guard availability == .installed else {
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
        } else if !clipboard.automaticAccessAllowed {
            statusText = "Clipboard access needed — open Setup"
        } else {
            clipboard.start()
            statusText = "Spanish → English · On-device"
        }
        refreshMenu()
    }

    @objc private func togglePause() {
        paused.toggle()
        UserDefaults.standard.set(paused, forKey: "paused")
        cancelCurrent()
        if paused { startIfAllowed() } else { Task { await checkReadiness() } }
    }

    @objc private func translateClipboard() { request(clipboard.currentText(), manual: true) }

    @objc func runDemo() {
        setupWindow?.orderOut(nil)
        request(Self.demo, manual: true)
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
                clipboard.stop()
                statusText = "Language downloads needed — open Setup"
                setupMessage = "Prepare Spanish and English to resume on-device translation."
                refreshMenu()
                return
            }
            card.show(source: source, copy: { [weak self] result in
                self?.clipboard.copyTranslation(result) ?? false
            }, setup: { [weak self] in self?.openSetup() })
        }
    }

    private func cancelCurrent() {
        generation = UUID()
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
        setupWindow?.orderOut(nil)
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
