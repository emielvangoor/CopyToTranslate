import AppKit
import SwiftUI
import Translation

struct SetupView: View {
    @ObservedObject var controller: AppController
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Copy. Translate. Refine.").font(.title2.weight(.semibold))
                    Text("Spanish translations and better Dutch, on your Mac.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text("Copy Spanish for an English translation. For Dutch, copy your text and press §. Your clipboard stays unchanged until you click a copy button.")
                .fixedSize(horizontal: false, vertical: true)
            Text(controller.setupMessage)
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 42, alignment: .topLeading)
            HStack {
                Button(controller.enabled ? "Prepare Languages" : "Enable Translation") {
                    if configuration == nil {
                        configuration = TranslationSession.Configuration(source: AppController.spanish, target: AppController.english)
                    } else {
                        configuration?.invalidate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(controller.preparing)
                if controller.preparing { ProgressView().controlSize(.small) }
                Spacer()
                Button("Try Example") { controller.runDemo() }
                    .disabled(!controller.enabled || controller.preparing)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable Dutch proofreading · §", isOn: Binding(
                        get: { controller.dutchEnabled },
                        set: { controller.setDutchEnabled($0) }
                    ))
                    .toggleStyle(.checkbox)
                    Text("Copy a Dutch sentence or email, then press §. Switch between Corrected and Improved phrasing, and copy either version.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error = controller.dutchShortcutError {
                        Text(error).font(.caption).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(controller.dutchSetupMessage)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Check setup") { Task { await controller.checkDutchSetup() } }
                            .disabled(controller.checkingDutch)
                        if controller.checkingDutch { ProgressView().controlSize(.small) }
                        Spacer()
                        Button("Try Dutch example") { controller.runDutchDemo() }
                            .disabled(!controller.enabled || !controller.dutchEnabled || controller.preparing)
                    }
                    .controlSize(.small)
                    DisclosureGroup("First-time Dutch setup") {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Install and open Ollama, then run this once in Terminal to download the 6.6 GB Dutch model. Keep Ollama running for Dutch proofreading.")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                            Link("Download Ollama", destination: URL(string: "https://ollama.com/download/mac")!)
                            Text("ollama pull qwen3.5:9b")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Text("Ollama’s login setting can keep it available after restarting your Mac.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, 6)
                    }
                    .font(.caption)
                }
                .padding(6)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at login", isOn: Binding(
                    get: { controller.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                Text("Start quietly in the menu bar when you sign in to your Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                if controller.loginItemNeedsApproval {
                    Text("Allow CopyToTranslate in System Settings to finish enabling startup.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open Login Items Settings") { controller.openLoginItemSettings() }
                }
                if let error = controller.loginItemError {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Look for the translation icon in your menu bar to pause or quit.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(26)
        .frame(width: 440)
        .translationTask(configuration) { session in
            await controller.prepare(using: session)
        }
    }
}
