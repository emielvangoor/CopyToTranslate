<p align="center"><img src="Resources/AppIcon.png" width="128" alt="CopyToTranslate app icon"></p>

# CopyToTranslate

**Copy Spanish. Read English. Stay in your flow.**

A small macOS menu bar app that automatically translates copied Spanish text into English in a quiet corner of your screen. Language detection and translation run on your Mac using Apple's Natural Language and Translation frameworks.

[Download the latest release](https://github.com/emielvangoor/CopyToTranslate/releases/latest) · [Release notes](https://github.com/emielvangoor/CopyToTranslate/releases) · [Report an issue](https://github.com/emielvangoor/CopyToTranslate/issues)

![macOS 15+](https://img.shields.io/badge/macOS-15%2B-555555)
![Apple silicon](https://img.shields.io/badge/Apple%20silicon-arm64-555555)
[![Build](https://github.com/emielvangoor/CopyToTranslate/actions/workflows/build.yml/badge.svg)](https://github.com/emielvangoor/CopyToTranslate/actions/workflows/build.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-555555)](LICENSE)

## What it does

- **Automatic Spanish detection.** Copy a Spanish passage in any app to see its English translation. Emoji are ignored for detection and preserved in the text sent to translation.
- **A quiet translation card.** Appears at the top right without taking keyboard focus. Longer translations scroll.
- **Copy English.** Copies the full translation when you click it. Otherwise, your original clipboard stays unchanged.
- **Five-second countdown.** A shrinking ring shows the remaining reading time. Hover to pause; move away to resume. Respects Reduce Motion.
- **Menu bar controls.** Pause or resume, translate ambiguous text manually, try an example, or open Setup.
- **Launch at login.** An optional Setup switch starts the app quietly when you sign in.

No accounts, API keys, subscription, or online translation provider.

## Install

Requires an **Apple silicon Mac (M-series)** running **macOS 15 Sequoia or later**. The downloadable build is arm64; Intel Macs are not currently a supported release target.

1. Download the `.zip` from the [latest release](https://github.com/emielvangoor/CopyToTranslate/releases/latest).
2. Unzip it and move **CopyToTranslate.app** into **Applications** before opening it.
3. Open the app and click **Enable Translation**. Approve Apple's Spanish and English language downloads if prompted. This one-time download needs an internet connection.
4. Allow clipboard access if macOS asks, then copy a Spanish sentence or click **Try Example**.
5. Turn on **Launch at login** in Setup if you want automatic startup.

The app lives in the menu bar and has no Dock icon. Closing Setup keeps it running.

### First launch and macOS security

These initial releases are ad-hoc signed and **not notarized by Apple**, so macOS may block the first launch. If you trust this download, try opening it once, then use **System Settings → Privacy & Security → Open Anyway**. See [Apple's instructions](https://support.apple.com/en-us/102445). You can also build from source below.

### Updating

Quit CopyToTranslate from its menu, replace the app in Applications with the new version, and reopen it. Check **Setup → Launch at login** after updating. Language models are managed by macOS. There is no built-in updater.

## Everyday use

Copy something like:

> La reunión se ha cambiado al jueves a las diez.

The card shows an English translation. Keep working, hover to read longer, or click **Copy English** to use the result elsewhere.

For short or ambiguous phrases, choose **Translate Clipboard as Spanish** from the menu bar. Use **Pause Translation** whenever you want copying to stay quiet.

## Privacy and limits

- Detection and translation run on-device. Initial language downloads are the only network setup the app needs; there is no cloud translation client, analytics, or clipboard history.
- Copied text and translations are not saved to files, logs, or preferences. Text is held for the current card and in-flight system translation work.
- Empty/non-text items, standalone URLs and email addresses, and selections over 10,000 characters are skipped. Uncertain language detection stays quiet.
- Recognized confidential/transient clipboard markers are skipped. Not all apps mark sensitive text, so these markers are not a complete sensitive-content filter.
- Startup, resume, and wake ignore existing clipboard content. Only subsequent clipboard changes are watched.
- New clipboard content dismisses the previous card. The app's own **Copy English** write does not trigger another translation.
- Sleep, screen lock, and inactive sessions suspend monitoring and hide the card. A floating card is an app window, so Focus does not automatically suppress it.
- Apple's translation quality can vary, particularly for slang and short phrases. Source and target languages are fixed to Spanish → English.

## Troubleshooting

| Problem | What to try |
| --- | --- |
| Nothing happens when copying | Check that translation is enabled and not paused. Try a complete Spanish sentence or **Test Translation** from the menu. |
| Short words are missed | Choose **Translate Clipboard as Spanish** to bypass automatic detection. |
| Language downloads are needed | Open **Setup → Prepare Languages** and let the downloads finish. |
| Clipboard access is needed | Allow CopyToTranslate's clipboard access in macOS settings where available, then enable translation again. |
| Automatic startup needs approval | Use **Open Login Items Settings** in Setup and allow the app there. |
| Translation fails | Copy the passage again, or open Setup to recheck language preparation. The original clipboard remains available. |

## Build from source

Use Xcode with the macOS SDK and **Swift 6**. The project has no third-party dependencies.

```sh
git clone https://github.com/emielvangoor/CopyToTranslate.git
cd CopyToTranslate
env -u LIBRARY_PATH swift test
./scripts/build-app.sh
open build/CopyToTranslate.app
```

The build script creates an ad-hoc signed app for the current Mac's architecture. Keep it at its registered location if you enable launch at login, or move it to Applications before enabling that setting.

Tests use private pasteboards and leave your clipboard untouched. They cover language detection, emoji handling, clipboard changes and preservation, confidential markers, copy suppression, countdown pause/resume, and overlapping suspension events. Actual translation-model downloads and translation UI are checked manually; see [verification notes](docs/verification.md).

## Releases

Tagged releases include the app ZIP and its SHA-256 checksum. GitHub also provides source archives. To verify a downloaded ZIP, put it and its `.sha256` file in the same folder and run:

```sh
shasum -a 256 -c CopyToTranslate-v1.0.0-macos-arm64.zip.sha256
```

Use the filename for your downloaded version. Maintainers can follow the [release guide](docs/releasing.md) to publish another version. Pull requests and pushes to `main` also run the tests and package verification in GitHub Actions.

## License

[MIT](LICENSE) © 2026 Emiel van Goor.
