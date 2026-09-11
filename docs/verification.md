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
