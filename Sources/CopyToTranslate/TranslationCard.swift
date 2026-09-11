import AppKit
import ClipboardCore
import SwiftUI
import Translation

@MainActor final class CardModel: ObservableObject {
    let source: String
    @Published var translation: String?
    @Published var error: String?
    @Published var copied = false
    @Published var copyFailed = false
    @Published var countdown: DismissalCountdown?
    private(set) var cancelled = false
    var onFinished: (() -> Void)?
    private var timeout: Task<Void, Never>?

    init(source: String) { self.source = source }

    func translate(using session: sending TranslationSession) async {
        guard !cancelled, translation == nil, error == nil else { return }
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, !cancelled, translation == nil else { return }
            error = "Translation took too long. Copy the text again to retry."
        }
        defer { timeout?.cancel(); timeout = nil }
        do {
            let response = try await session.translate(source)
            guard !Task.isCancelled, !cancelled, error == nil else { return }
            guard !response.targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                error = "No translation was returned. Copy the text again to retry."
                return
            }
            translation = response.targetText
            onFinished?()
        } catch {
            guard !Task.isCancelled, !cancelled, self.error == nil else { return }
            self.error = "Couldn’t translate this text. Try again, or open Setup to check language downloads."
        }
    }

    func cancel() {
        cancelled = true
        timeout?.cancel()
        timeout = nil
        translation = nil
        error = nil
        countdown = nil
        onFinished = nil
    }
}

private final class CornerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class TranslationPanel {
    private var panel: NSPanel?
    private var model: CardModel?
    private var dismissal: Task<Void, Never>?
    private var hovered = false

    func show(source: String, copy: @escaping (String) -> Bool, setup: @escaping () -> Void) {
        hide()
        let model = CardModel(source: source)
        self.model = model
        model.onFinished = { [weak self] in self?.beginCountdown() }
        let panel = CornerPanel(contentRect: NSRect(x: 0, y: 0, width: 370, height: 240),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Spanish to English"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: TranslationCard(
            model: model, copy: copy,
            close: { [weak self] in self?.hide() },
            hover: { [weak self] inside in self?.setHovered(inside) },
            setup: setup
        ))
        self.panel = panel
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 18, y: frame.maxY - panel.frame.height - 18))
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        dismissal?.cancel()
        dismissal = nil
        model?.cancel()
        model = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        hovered = false
    }

    private func setHovered(_ inside: Bool) {
        guard inside != hovered else { return }
        hovered = inside
        let now = ProcessInfo.processInfo.systemUptime
        if inside { model?.countdown?.pause(at: now) }
        else { model?.countdown?.resume(at: now) }
        scheduleDismissal()
    }

    private func beginCountdown() {
        model?.countdown = DismissalCountdown(startedAt: ProcessInfo.processInfo.systemUptime, paused: hovered)
        scheduleDismissal()
    }

    private func scheduleDismissal() {
        dismissal?.cancel()
        dismissal = nil
        guard let model, let countdown = model.countdown, !countdown.isPaused else { return }
        let remaining = countdown.remaining(at: ProcessInfo.processInfo.systemUptime)
        dismissal = Task { [weak self, weak model] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, let self, let model, self.model === model else { return }
            hide()
        }
    }
}

private struct TranslationCard: View {
    @ObservedObject var model: CardModel
    let copy: (String) -> Bool
    let close: () -> Void
    let hover: (Bool) -> Void
    let setup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Spanish → English", systemImage: "character.bubble")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Close translation")
                    .help("Close translation")
            }
            if let translation = model.translation {
                ScrollView {
                    Text(translation)
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("translationText")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    if model.copyFailed {
                        Text("Couldn’t copy. Try again.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if let countdown = model.countdown {
                        CountdownIndicator(countdown: countdown)
                    }
                    Spacer()
                    Button {
                        model.copied = copy(translation)
                        model.copyFailed = !model.copied
                    } label: {
                        Label(model.copied ? "Copied!" : "Copy English", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("copyEnglish")
                }
            } else if let error = model.error {
                Text(error).font(.callout).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Open Setup", action: setup).controlSize(.small)
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Translating on your Mac…").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .frame(width: 370, height: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
        .onHover(perform: hover)
        .translationTask(source: AppController.spanish, target: AppController.english) { session in
            await model.translate(using: session)
        }
    }
}

private struct CountdownIndicator: View {
    let countdown: DismissalCountdown
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30, paused: countdown.isPaused)) { _ in
            let remaining = countdown.remaining(at: ProcessInfo.processInfo.systemUptime)
            let seconds = Int(ceil(remaining))
            HStack(spacing: 6) {
                if reduceMotion {
                    Image(systemName: countdown.isPaused ? "pause.circle" : "timer")
                        .frame(width: 14, height: 14)
                } else {
                    ZStack {
                        Circle().stroke(.primary.opacity(0.12), lineWidth: 1.7)
                        Circle()
                            .trim(from: 0, to: remaining / countdown.duration)
                            .stroke(countdown.isPaused ? Color.secondary : Color.accentColor,
                                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        if countdown.isPaused {
                            Image(systemName: "pause.fill").font(.system(size: 5, weight: .bold))
                        }
                    }
                    .frame(width: 14, height: 14)
                }
                Text(countdown.isPaused ? "Paused" : "Closes in \(seconds)s")
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(countdown.isPaused
                ? "Auto-close paused, \(seconds) seconds remaining"
                : "Closes in \(seconds) seconds")
            .accessibilityIdentifier("dismissalCountdown")
            .help("Hover over the card to pause the countdown.")
        }
    }
}
