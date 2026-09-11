# Verification — 11 September 2026

Environment: Apple silicon Mac, macOS 15.6, Swift 6.2 and Xcode macOS SDK.

- Eight automated tests pass using actual NaturalLanguage recognition and isolated NSPasteboards. Coverage includes language filtering, content limits, initial-clipboard suppression, one event per change, clipboard preservation, Copy English suppression, confidential markers, pause/resume baselines, and overlapping sleep/lock/session suspension.
- Release bundle builds successfully; Info.plist validation and strict ad-hoc code-signature verification pass.
- The actual setup UI downloaded Apple's Spanish and English language models and reached Ready.
- The built-in Spanish example translated successfully through Apple's TranslationSession.
- Copy English produced a result that was pasted into a fresh TextEdit document and checked in the accessibility tree.
- Copying `¿Puedes enviarme la factura cuando tengas un momento?` in TextEdit automatically displayed `Can you send me the invoice when you have a moment?` in the corner card. TextEdit retained the selection/focus.
- Pasting after that automatic translation still pasted the Spanish original.
- Visual inspection confirmed the card layout and Copy English → Copied! feedback.
- Independent review identified overlapping suspension reasons and setup overriding pause; both were corrected. Preparation also checks lock/pause state before its explicit clipboard-access read.

No network disconnection, actual screen-lock cycle, multiple-monitor setup, or other macOS version was exercised during verification. The local translation claim relies on the selected Apple on-device framework; no online provider client is present in the application.

## Countdown and emoji update

- Added a shared monotonic countdown for the visible ring and actual dismissal, now set to five seconds at the user's request. Four tests cover expiry, hover pause/resume without resetting, duplicate hover events, and hovering before translation completes.
- Visually checked the countdown ring and live seconds label in the running app; observed the translated card being dismissed.
- Reproduced the user's emoji-rich Spanish message failing raw language recognition. Removing symbols from recognition input changes the Spanish score to greater than 0.9999. The original text still goes to translation.
- Added regression coverage for that exact message, emoji-rich English, emoji-only input, and preservation of decomposed accents in the original text.

## Launch at login

- Added a Setup checkbox backed by `SMAppService.mainApp`, including unregistering, errors, approval guidance, and refreshing status when the app becomes active or Setup opens. No separate preference overrides the system setting.
- Enabled the checkbox in the running app. macOS's `sfltool dumpbtm` reports `com.emiel.CopyToTranslate` as `[enabled, allowed, visible, notified]`, pointing to `/Users/emiel/Code/Sides/CopyToTranslate/build/CopyToTranslate.app/`.
- Visually checked the Setup layout and enabled checkbox. All 15 existing tests pass, the release build succeeds, and strict code-signature verification passes.
- An actual logout or reboot was not performed during verification.

## Public release packaging

- All 15 automated tests pass with the release changes. The arm64 app builds, its Info.plist validates, and its ad-hoc signature verifies.
- The packaging script extracts the release ZIP into a temporary directory, verifies the extracted signature and executable, compares the executable with the original, and validates its SHA-256 checksum.
- The custom icon has an alpha channel, is converted to the standard macOS icon sizes, and is visible in the running Setup window. Launch at login remained enabled after restarting the updated app.
- The README includes installation, local privacy behavior, troubleshooting, source builds, updates, and the unnotarized build limitation. The repository and bundled app include the user-selected MIT license.
