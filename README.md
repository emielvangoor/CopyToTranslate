# CopyToTranslate

A small macOS menu bar app. Copy Spanish text and read an English translation in the top-right corner. Detection and translation run on your Mac using Apple's Natural Language and Translation frameworks.

## Run

Requires macOS 15 or later. The first build targets the architecture of the Mac it is built on; this project is developed on Apple silicon.

```sh
cd /Users/emiel/Code/Sides/CopyToTranslate
./scripts/build-app.sh
open build/CopyToTranslate.app
```

Click **Enable Translation** in the setup window. If needed, approve Apple's Spanish/English language download. Initial downloads require an internet connection; translation runs on-device once those models are installed.

Use **Try Example** to check the result. Then copy a Spanish sentence in any app. A small card appears without taking keyboard focus. It closes after 5 seconds of reading time, with a shrinking ring and a “Closes in …s” label. Hovering pauses the countdown and shows “Paused”; moving away resumes the remaining time. Reduced Motion uses a static timer icon instead of the animated ring. Longer translations scroll inside the card.

Click **Copy English** to put the complete English translation on your clipboard. Otherwise, the original clipboard is preserved.

Look for the translation speech-bubble icon in the menu bar. Its menu contains Pause/Resume, Translate Clipboard as Spanish (for ambiguous words), Test Translation, Setup, and Quit. The app stays in the menu bar when its setup window closes; there is no Dock icon.

Turn on **Setup → Launch at login** to start quietly in the menu bar whenever you sign in. This uses macOS's native login-item registration and reflects the system setting. Turn it off in Setup to stop automatic startup. If macOS requires approval, Setup provides a button to open Login Items settings. Keep the built app at its registered location; rebuilding with the script updates that same app.

## Privacy and behavior

- No accounts, API keys, online translation provider, analytics, or clipboard history.
- Detection always runs locally. English and uncertain text remain quiet.
- Emojis and symbols are excluded from language detection so they cannot overwhelm the Spanish signal. The full original passage is still used for translation.
- Recognized confidential/transient clipboard markers are skipped. These markers do not identify all sensitive content; pause monitoring when appropriate.
- Empty/non-text items, standalone URLs/email addresses, and selections over 10,000 characters are skipped.
- Startup and resume ignore preexisting clipboard content. Only subsequent changes are watched.
- New clipboard content dismisses the previous card and invalidates its result. Copy English does not trigger another translation.
- Locking/sleep hides the card and stops monitoring; waking starts from a fresh baseline.
- No copied text or translations are written to logs or preferences. Text is held only for the active card and in-flight system translation work.
- The floating card is an app window, so Focus does not automatically hide it. Use Pause when needed.

## Build and test

Xcode with the macOS SDK and Swift 6 is required. There are no third-party dependencies.

```sh
env -u LIBRARY_PATH swift test
./scripts/build-app.sh
codesign --verify --strict build/CopyToTranslate.app
```

The tests use private pasteboards, leaving the user's real clipboard untouched. They exercise actual language detection, change handling, confidential content, pause/resume, and Copy English.

The build script creates an ad-hoc signed local app. Distribution to other people would require a Developer ID signature and notarization.

## Troubleshooting

- **No translation:** verify the menu is active, try a complete Spanish sentence, or choose Test Translation. Very short words may be ambiguous.
- **Language downloads needed:** open Setup and click Prepare Languages. Downloads are managed by macOS.
- **Clipboard access needed:** allow access for CopyToTranslate in macOS settings where that control is available, then enable translation again. The app does not repeatedly request access in the background.
- **Translation error:** copy the passage again. Setup can recheck language preparation. The original clipboard remains available.

OpenRouter and other online engines are intentionally deferred until the local translation quality has been evaluated.
