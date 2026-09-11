# CopyToTranslate — functional description

Draft for review · 11 September 2026

**Latest behavior:** Auto-close uses a visible **5-second** countdown ring. Hover pauses and leaving resumes the remaining time. Language detection excludes emoji/symbols, while translation receives the original passage. These user-requested updates supersede the original timing defaults below.

**Implementation update:** The user selected the simplest fully on-device first version. Its scope is setup, menu bar pause/resume, manual/demo translation, and one scrollable top-right card with Copy English and Close. Launch at login is now included at the user's request: a Setup checkbox controls macOS's native login-item registration, with a link to System Settings if approval is needed. Once translation is enabled, startup stays quietly in the menu bar. OpenRouter, history, display preferences, and a separate expanded window are deferred. The detailed sections below remain the broader design reference; the implementation plan records the narrowed release scope.

## Purpose

CopyToTranslate is a small macOS menu bar application that helps an English-speaking user understand Spanish text without switching applications. When the user copies Spanish text, the app automatically displays its English translation in a compact card in a screen corner.

The user continues copying and pasting normally. Displaying a translation does not change the clipboard or take keyboard focus away from the application being used.

This document describes the proposed first version and an optional OpenRouter extension. Confirmed preference: language detection must always run on the Mac, and translation should run locally by default. OpenRouter may be used for translation if it adds value. A manual second-translation action is the proposed way to keep routine copying free of LLM requests. Timing, size, and detection thresholds below are proposed product defaults, not measured performance claims.

## Everyday experience

1. The app runs in the menu bar after the user opens it, optionally starting at login.
2. The user selects text in an application and copies it using Command-C or a Copy command.
3. CopyToTranslate notices that the clipboard has changed and checks eligible text locally.
4. If the text is confidently identified as Spanish, the app translates it into English on the Mac.
5. A small card appears in the upper-right corner of the display containing the pointer when the copy is detected.
6. The user reads the translation and carries on working. The card disappears automatically after 10 seconds, measured from when the translation appears.

Example:

> Copied: «La reunión se ha cambiado al jueves a las diez.»
>
> Card: “The meeting has been moved to Thursday at ten.”

If the user then presses Command-V in another application, the original Spanish text is pasted. Only the card’s **Copy English** action deliberately replaces the clipboard with the English translation.

## Translation card

The card is a custom floating panel with a proposed width of approximately 360 points. It sits inside the display’s usable area, clear of the menu bar and Dock. The user can select any of the four screen corners in Settings.

The English translation is the main content. A small “Spanish → English” label identifies its purpose. The card contains three actions: **Copy English**, **Expand**, and **Close**.

The card appears without activating the app, moving the cursor, interrupting typing, or playing a sound. It accepts mouse interaction within its own bounds; the surrounding desktop remains usable. Hovering over it pauses the dismissal timer. Moving away restarts the configured timer, which defaults to 10 seconds.

The compact view shows up to approximately six lines. Longer results have a clearly marked preview; **Expand** opens a scrollable reading view with the complete English translation and original Spanish text. Expanding is an explicit user action and may activate that reading window. It remains open until closed, and new clipboard activity does not replace the text the user is reading.

There is at most one automatic card. A new eligible copy replaces the previous card rather than stacking another. Copying something ineligible dismisses the old automatic card so it cannot be mistaken for a translation of the new clipboard contents. An explicitly opened reading window remains unchanged.

The panel follows macOS light/dark appearance and reduced-motion preferences. Controls have accessibility labels, and the reading view is keyboard accessible through the menu bar.

## What triggers translation

The first version accepts plain text, including the plain-text representation of copied formatted text. It preserves paragraph breaks where possible. It does not perform OCR on images or open copied files and URLs.

| Clipboard content | Proposed behavior |
| --- | --- |
| A clearly Spanish sentence or paragraph | Automatically translate to English. |
| A distinctive Spanish word such as “gracias” | Translate if recognition is sufficiently confident. |
| English or another identified language | Remain quiet. |
| Ambiguous short text such as “no” or “a” | Remain quiet; a manual action is available. |
| Mixed languages | Translate the selection only when Spanish is confidently dominant; sentence-by-sentence language routing is outside version one. |
| Empty text, numbers only, a standalone URL, or a standalone email address | Ignore. |
| Images, files, or content without a usable text representation | Ignore. |
| Text marked confidential by its source application using recognized clipboard conventions | Ignore; recognition of these markers is best effort. |
| More than 10,000 characters | Skip automatic translation and expose “Selection too long — copy a shorter passage” in the menu. Never silently translate only a prefix. |

Language detection always runs locally, including when the optional OpenRouter extension is configured. No clipboard content is sent to an LLM to identify its language or resolve uncertainty.

The initial recognition policy requires at least four alphabetic characters, Spanish as the highest-ranked candidate, and a candidate score of at least 0.80. This score is a recognizer heuristic, not a guarantee of correctness. Validate the threshold against representative Spanish, English, Catalan, Portuguese, names, and short phrases before release. Do not restrict detection to Spanish and English, which could force other languages into the wrong category.

Apple supplies language identification and candidate scores through its [Natural Language framework](https://developer.apple.com/documentation/naturallanguage/identifying-the-language-in-text).

The menu offers **Translate Clipboard as Spanish** for short or ambiguous selections. This bypasses language detection, while preserving clipboard access, content-size, and confidential-content restrictions. The action remains available while automatic translation is paused.

## Repeated copies and interruptions

The watcher reacts to clipboard changes rather than intercepting Command-C. Copy commands, cuts, and other applications writing text to the general clipboard can therefore all trigger the same behavior; the clipboard does not provide a reliable distinction between them. Apple documents the general pasteboard and its change counter through [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard).

Repeatedly observing an unchanged clipboard does nothing. A new copy of the same text refreshes an already visible matching card; if the card was dismissed, the new copy can show it again. The app ignores the clipboard change caused by its own **Copy English** action.

When new clipboard content arrives, pending work for older content is cancelled where possible, and any late results are discarded. Only the latest eligible selection may produce an automatic card. Once the user opens a reading window, that window owns a fixed snapshot until closed.

Starting, resuming, or waking the app establishes a fresh clipboard baseline. It waits for the next change instead of automatically translating content already present. While paused, locked, or asleep, automatic clipboard reads and translations stop. Locking or quitting also hides translation windows and clears retained text.

## Menu bar and settings

The menu bar communicates **Active**, **Paused**, or **Setup needed** using an accessible label and a subtle icon state.

The menu contains:

- Pause/Resume automatic translation.
- Translate Clipboard as Spanish.
- Show Last Translation, available for up to five minutes after the latest successful translation.
- Settings.
- Quit.

Settings contain automatic translation on/off, start at login, card corner, dismissal duration (5, 10, or 20 seconds), and language-download/access status. Source and target remain fixed to Spanish and English in version one. If the optional OpenRouter extension is included, a separate initially disabled section contains its API key and translation-model selection.

Pausing immediately hides the automatic card and cancels automatic work. It remains paused across restarts until resumed. An explicitly opened reading window can remain available while paused.

## First launch and privacy

First launch opens a short setup window explaining that the app needs to inspect newly copied text to identify Spanish. Language detection necessarily reads candidate text before knowing whether it is Spanish.

Setup checks translation availability, prepares Spanish and English language downloads if needed, explains clipboard access, and provides a test using a supplied Spanish example. Automatic monitoring begins only after the user enables it. Starting at login is a separate, initially off option.

Apple’s Translation API uses on-device models and supports preparing language downloads in advance. Once the required models are installed, the proposed default workflow translates locally without sending clipboard text to a translation provider. Initial downloads need connectivity. See Apple’s [Translation API overview](https://developer.apple.com/videos/play/wwdc2024/10117/).

Apple also documents pasteboard privacy controls that can allow, deny, or prompt for programmatic access. Setup must handle the behavior present on the user’s macOS version. If continuous access is blocked, show **Setup needed** with instructions; do not repeatedly trigger permission prompts or claim monitoring is working. The precise rollout and available controls must be tested on the supported macOS versions. See [AppKit’s pasteboard privacy changes](https://developer.apple.com/documentation/updates/appkit?changes=latest_ma_3).

The app saves preferences but does not maintain a clipboard history or log source text and translations. It retains the latest successful source/result pair in memory for a maximum of five minutes for **Show Last Translation**; an open reading window retains its own copy only while open. New successful translations replace the retained last result. Locking and quitting clear both. The app itself does not sync content or automatically fall back to an online service.

Confidential clipboard markers are an additional precaution, not comprehensive secret detection. A pause control is available before copying content the user does not want inspected. This design does not require screen capture or keystroke interception.

## Optional OpenRouter translation

Build and evaluate the local workflow first. OpenRouter is an optional translation extension if the user finds local translations insufficient, particularly for informal or context-dependent passages. Better quality is something to compare on real examples, not assume merely because an LLM is used.

When configured, the expanded reading view offers **Try with OpenRouter**. Clicking it sends the displayed source passage for a separate English translation. The action identifies that it uses an online model; setup has already explained that the passage is sent through OpenRouter to the selected provider. It does not send other clipboard entries, application contents, or conversation history. Ordinary copying, local recognition, and uncertain language detection never trigger this action automatically.

The second result appears alongside the local translation with an **OpenRouter** label and model name. The user can compare and copy either result. Both remain tied to the reading window’s fixed source passage, even if the clipboard changes. For a passage the user manually identified as Spanish, the same action is available after opening its reading view. Content-size and recognized-confidential-content restrictions still apply.

Each click starts at most one request. Disable the action while a request is running, retain the result with the reading window, and make any subsequent paid retry explicit. Do not automatically retry errors or route to another model. Supply only a short translation instruction and the selected passage, set a bounded output allowance, and treat copied instructions as source material to translate. The LLM has no tools or authority to take actions.

The user supplies a normal OpenRouter API key, stored in macOS Keychain rather than plain preferences or logs. Recommend a dedicated key with a spending limit configured in OpenRouter; its key API supports [spending limits](https://openrouter.ai/docs/api/api-reference/api-keys/create-keys). The app does not need a management key. Model selection should follow a small Spanish-to-English quality, latency, and price comparison during implementation, without changing the always-local detector.

Online processing does not inherit the app’s local-only retention policy. Provider training and retention policies differ, as shown in OpenRouter’s [provider directory](https://openrouter.ai/providers/). Configure appropriate provider restrictions and explain the selected policy during setup before enabling online translation.

If offline, credentials are invalid, a spending limit is reached, or no response arrives within 30 seconds, preserve the local result and show a concise error next to the online action. Closing the window, locking, or quitting cancels pending requests where possible and discards late results. Cancelling locally cannot guarantee that a submitted request was not processed or charged remotely.

## Delays, errors, and display behavior

For an ordinary short paragraph with models ready, the product target is to show a translation within roughly two seconds; verify actual performance on supported hardware. If translation takes more than one second, show a quiet “Translating…” card. After 15 seconds without completion, show “Couldn’t translate this text” with **Retry** and **Close**. Retry applies only to that still-current selection.

Missing models, unsupported translation availability, or denied clipboard access produce a persistent menu status with a setup action. They do not generate a new error card on every clipboard change. Non-Spanish and uncertain text produce no error.

The card should appear on the current desktop Space, including ordinary full-screen app Spaces where macOS permits it, without switching Spaces. Display reconnection must keep the card within an available screen. Exclusive full-screen behavior requires testing; if presentation is unavailable, the translation can be retrieved from the menu.

Because the proposed card is an application window, macOS notification settings do not automatically control it. Version one uses the app’s Pause control to suppress cards; automatic integration with Focus or screen-sharing state is outside scope.

## Implementation outline and alternatives

A native Swift application is the proposed approach: a menu bar controller, a lightweight clipboard watcher, local language detection, an asynchronous translation service, and a floating AppKit panel with SwiftUI content. The watcher can start with a 500 ms change-counter check while active, reading and processing text only after a change. This is a proposed implementation, not a benchmarked power profile.

Use Apple’s Translation framework behind a small internal interface. The first implementation checkpoint must verify repeated translation while the app is inactive, including translation-session lifetime and any UI required for model setup. Confirm hardware and minimum macOS support from that prototype before promising a compatibility range.

| Approach | Fit and trade-off |
| --- | --- |
| Native menu bar app, local translation, custom card — recommended | Matches the requested automatic experience, supports offline use after setup, and permits control over placement, duration, and long-text reading. Requires native window and translation lifecycle work. |
| Local workflow with a manual OpenRouter second translation | Preserves local detection and automatic translation while allowing selected passages to use another engine. Adds network dependency and usage charges only when the online action is used. Optional extension. |
| System notification for each translation | Uses familiar system presentation, but the app has less control over card placement and reading interactions. Less suited to longer passages. |

## Acceptance criteria for the first version

1. Copying a clearly Spanish sentence in Safari, Mail, or another app produces an English translation without changing the active application or keyboard focus.
2. Pasting after the automatic translation still pastes the original clipboard content. **Copy English** deliberately copies the English result and does not cause a translation loop.
3. English, ambiguous short text, non-text items, and recognized confidential items remain quiet under the stated rules.
4. Rapid copies of A then B never display a late result for A after B becomes current. This also holds if B is ineligible.
5. The card dismisses on the configured timer, pauses on hover, supports expansion, and remains readable in light/dark appearance and on multiple displays.
6. An expanded translation remains stable when another selection is copied.
7. After setup and model downloads, Spanish-to-English translation works with internet connectivity disabled.
8. Denied access, missing models, timeouts, sleep/wake, and pause/resume recover according to the behavior above without repeated prompts or stale cards.
9. No copied text or translation is written to application logs or a history database. The retention limits and clearing on lock/quit work as described.
10. Idle operation performs no repeated language detection or translation when the clipboard is unchanged; energy use and translation latency are measured on the declared supported devices.
11. With OpenRouter configured, copying Spanish, English, ambiguous text, and other clipboard items still produces zero LLM requests until the user explicitly invokes the online action.
12. If the OpenRouter extension is included, invoking it submits only the reading window’s source passage plus the translation instruction, submits once, and preserves the local result through errors or later clipboard changes. Keys never appear in preferences or logs.

The first version is complete when the automatic local workflow meets the applicable criteria. The optional OpenRouter extension adds the online criteria without changing local detection. Additional languages, automatic cloud translation, persistent history, OCR, speech, automatic clipboard replacement, and per-application rules are future scope.
