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

No network disconnection, actual screen-lock cycle, multiple-monitor setup, or other macOS version was exercised during verification. For v1.0.0, the local translation claim relies on the selected Apple on-device framework. The 1.1.0 development updates below add an online provider only for explicit Dutch proofreading.

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

## Dutch proofreading and § shortcut (1.1.0 development)

- All 29 automated tests pass. New coverage includes Dutch prose/code/name eligibility, emoji preservation, structured output validation, loopback request construction, changed numbers/links/email rejection, corrected/improved copying and stale async results. The immediate-copy/shortcut regression verifies that the next clipboard poll does not cancel the manually requested card.
- Registered the unmodified ISO section key with Carbon. Setup reports no registration error, and `UCKeyTranslate` confirms that key code 10 produces § on this Mac's Dutch keyboard layout. The automation tool cannot synthesize this particular key, so a physical § press was not automated. The menu/demo pipeline and real card were exercised.
- Downloaded and evaluated qwen3.5:9b through local Ollama. Synthetic sentences and emails exercised verb endings, spelling, punctuation, phrasing, paragraphs, names, dates, numbers, email addresses and emoji. An embedded request to answer in English was treated as text and remained in Dutch. The smaller 4b trial model introduced grammar errors during rephrasing and was removed.
- Warm responses on this Mac took approximately 2–9 seconds for the tested passages; the first 9b request took about 27 seconds. Model quality is not guaranteed: minimal edits can still change wording, and qualified or nuanced wording needs review. No general Dutch-quality score is claimed.
- In the real card, Corrected is selected first. Copy corrected pasted the complete corrected result into a fresh TextEdit document. Selecting Improved phrasing changed the wording and button label; Copy improved pasted that exact version. Both actions showed Copied!, and the card retained its five-second countdown.
- With Setup closed, copying a Spanish sentence in TextEdit automatically displayed its English translation and kept the TextEdit selection. The built-in Spanish example also worked after the final rebuild.
- Setup visibly retains Dutch proofreading enabled and Launch at login enabled after restart. Ollama runs as the user's Homebrew service, configured to start at login. No reboot was performed.
- The final arm64 app and development ZIP pass strict ad-hoc signature checks, plist validation, extracted executable comparison and SHA-256 validation. Setup text wraps without truncation. The public v1.0.0 release is unchanged.
- No live redirect server, offline-network switch, shortcut collision with another app, or real screen-lock cycle was exercised. Redirect blocking and loopback restriction were reviewed in code; clipboard confidentiality and suspension state have automated coverage.

## OpenRouter and selected-text update (1.1.0 development, build 5)

- Replaced Ollama with GPT-5.4 nano through OpenRouter after testing the reported failure. The real app now produces `Dit is een test.` from `did is een  test`, and both copy buttons pasted the expected complete result into TextEdit.
- Nine synthetic API evaluations passed their expected checks, including spelling, verb endings, capitalization, punctuation, preserved numbers/contact details, paragraphs and embedded instructions. They took about 1–3 seconds each and cost $0.00142835 total. GPT-4.1 mini failed the typo/capitalization checks. Full examples and limits are in [Dutch evaluation](dutch-evaluation.md).
- Real key was saved through the app's secure field into macOS Keychain. Saving clears the editor; closing/reopening Setup clears an unsaved dummy key. Restarting the rebuilt app successfully checked the saved key without re-entry. No credential is included in source, documentation or bundles.
- The obsolete Ollama service is stopped and unloaded; its trial models have been removed (model directory now 20 KB).
- All 39 automated tests pass. New checks cover local Spanish/Dutch shortcut routing, selected text taking precedence without reading the clipboard, no-selection fallback, access errors never falling back, stale clipboard-poll suppression and informational cards never starting cloud requests.
- Accessibility was approved in System Settings and an app restart made Setup report selected-text access allowed. A later ad-hoc rebuild invalidated that approval, so local builds now use the user’s existing personal Apple Development certificate through an ignored `.signing-identity` file. The final identity is stable across builds. The stale Accessibility entry was subsequently reset and the current signature approved successfully; see the recovery notes below. A physical § test remains outside the UI automation tool’s supported key set. The OpenRouter key and launch at login persist after restarting the final signed build.
- The AX reader requests only the focused element's selected text, rejects secure text fields, uses bounded messaging timeouts and checks the foreground app again before using the result. It neither synthesizes Copy nor reads the document's full value. Unsupported selection APIs show a visible fallback message.
- Automatic Spanish translation was exercised again through Apple's on-device session after the OpenRouter update. Correction and improved copy actions, countdown and Keychain persistence were checked in the running app.
- The public v1.0.0 release remains unchanged. The final local development arm64 ZIP verifies its Apple Development signature, extracted executable, plist and SHA-256 checksum. CI/default source builds remain ad-hoc signed; no notarization is claimed.

## Accessibility grant recovery

- Reproduced System Settings showing the CopyToTranslate switch enabled while the running app reported access denied. Only one CopyToTranslate process was running, from the expected build path, with the current personal Apple Development signature.
- macOS `tccd` logs explicitly reported “Failed to match existing code requirement” for this app’s Accessibility request. The stored requirement was the hash of an older ad-hoc build; the current app uses an Apple certificate requirement. This confirmed that toggling the displayed switch had left a stale code requirement in place.
- Stopped only CopyToTranslate and used the supported, app-specific command `tccutil reset Accessibility com.emiel.CopyToTranslate`. It reported success. Relaunched the same signed bundle and requested Accessibility access; System Settings then showed a fresh disabled entry for CopyToTranslate. User authentication is required to enable the new entry. No other app’s permissions were reset.
- After the user approved Touch ID, System Settings showed the new entry enabled. The existing process still reported its cached denied status. Restarting the unchanged, signed app made Setup report **Selected text access allowed**, with the OpenRouter key checked and launch at login still enabled. No additional rebuild or signature change was made.


## WhatsApp selection capture (1.1.0 development, build 6)

- The reported highlighted Spanish message classifies as Spanish locally. In native WhatsApp, the focused Accessibility element remains the compose field while a received message is visibly highlighted. Ordinary Edit > Copy was disabled, but right-clicking the highlight exposed a Copy-only menu. Invoking that menu copied the exact selected message, verified by pasting into a TextEdit fixture.
- Added pointer-based message capture for WhatsApp. It first tries direct selected text on the hit element/message, then accepts only WhatsApp's selection-only Copy menu. A fresh clipboard write must occur verbatim within that hit-tested message's Accessibility description/value. Only the copied selection reaches classification. Reading the message description is transient and is never logged or sent in full.
- Unlike direct selection capture, WhatsApp's Copy fallback leaves the selected source on the clipboard. There is no restoration transaction: an unrelated or late clipboard write is never overwritten by the app. Invalid, unavailable, timed-out or cancelled selection capture never uses an old clipboard item. Only a positively identified composer may use the regular selected-field reader, bound to the original process.
- All 47 automated tests pass, including unrelated clipboard writes, missing/late Copy, cancellation, focus changes, protected markers, selection-only menu checks, message validation and Spanish routing. Accessibility calls use per-element timeouts; traversal and cleanup have deadlines. Repeated shortcut captures are serialized through cleanup.
- The signed arm64 app and development ZIP pass strict signature checks, plist validation, extracted executable comparison and SHA-256 verification. The installed app uses the original ISO section key, not the temporary test key. Setup still reports Accessibility allowed, the Keychain key checked and launch at login enabled.
- The complete WhatsApp select → physical § → translated card flow is awaiting the user's test. The UI automation tool cannot synthesize §; the manual context-menu Copy operation and classifier were tested separately. This build does not claim compatibility with all WhatsApp versions or selections spanning multiple message bubbles. The public v1.0.0 release is unchanged.
