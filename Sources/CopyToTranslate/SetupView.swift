import AppKit
import SwiftUI
import Translation

struct SetupView: View {
    @ObservedObject var controller: AppController
    @State private var configuration: TranslationSession.Configuration?
    @State private var apiKey = ""

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
                    Text("Spanish translations and Dutch proofreading.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text("Copy Spanish for an English translation. Select Spanish or Dutch text and press § to translate or correct it. Copy the result with the button on its card.")
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
                    Toggle("Translate or correct selected text · §", isOn: Binding(
                        get: { controller.dutchEnabled },
                        set: { controller.setDutchEnabled($0) }
                    ))
                    .toggleStyle(.checkbox)
                    Text("Press § to translate Spanish on your Mac or correct Dutch through OpenRouter and OpenAI. Detection stays on your Mac. In text fields, § uses your clipboard when nothing is selected. In WhatsApp, keep the pointer over your highlighted message; § may copy that source text to read it.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error = controller.dutchShortcutError {
                        Text(error).font(.caption).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Label(controller.selectionAccessAllowed ? "Selected text access allowed" : "Selected text needs Accessibility access",
                              systemImage: controller.selectionAccessAllowed ? "checkmark.circle" : "hand.raised")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(controller.selectionAccessAllowed ? "Settings…" : "Allow…") {
                            controller.openSelectionAccessSettings()
                        }
                        .controlSize(.small)
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
                    DisclosureGroup(controller.hasOpenRouterKey ? "API key stored in Keychain" : "Add OpenRouter API key") {
                        VStack(alignment: .leading, spacing: 7) {
                            SecureField(controller.hasOpenRouterKey ? "Replace API key" : "OpenRouter API key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("openRouterAPIKey")
                            HStack {
                                Button("Save key") {
                                    if controller.saveOpenRouterKey(apiKey) { apiKey = "" }
                                }
                                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                if controller.hasOpenRouterKey {
                                    Button("Remove key") { apiKey = ""; controller.removeOpenRouterKey() }
                                }
                                Spacer()
                                Link("Get an API key", destination: URL(string: "https://openrouter.ai/settings/keys")!)
                            }
                            .controlSize(.small)
                            Text("Your key is saved only in this Mac’s Keychain. Dutch proofreading requires an internet connection and OpenRouter credit.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
        .onDisappear { apiKey = "" }
        .onChange(of: controller.keyEditorRevision) { apiKey = "" }
        .translationTask(configuration) { session in
            await controller.prepare(using: session)
        }
    }
}
