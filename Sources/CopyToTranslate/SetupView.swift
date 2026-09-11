import SwiftUI
import Translation

struct SetupView: View {
    @ObservedObject var controller: AppController
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Copy Spanish. Read English.").font(.title2.weight(.semibold))
                    Text("A quiet translation in the corner of your screen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text("When enabled, CopyToTranslate checks newly copied text on this Mac. Spanish text is translated locally. Your clipboard stays unchanged until you click Copy English.")
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
