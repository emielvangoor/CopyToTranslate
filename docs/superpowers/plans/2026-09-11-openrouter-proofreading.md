# OpenRouter Dutch proofreading

The user approved replacing local Dutch proofreading with OpenRouter and supplied an API key for this app. Spanish translation and language detection remain on-device. Only an explicit § press, menu command or built-in example sends Dutch text to OpenRouter. Corrected and Improved phrasing remain copyable and share the existing countdown.

Use GPT-5.4 nano with low reasoning effort, strict JSON output and no-training provider routing. GPT-4.1 mini failed the quality checks; nano passed the original failed typo and synthetic sentences/emails through the real API. Keep credentials in macOS Keychain, never in the repository, app bundle, preferences or logs. Setup includes a secure key editor, check/save/remove controls and a concise explanation of cloud processing. Removing or replacing the key cancels the current card. Do not silently fall back to another model.

Tests cover request destination/auth separation, response completeness/refusals, protected content, auth/credit/rate-limit errors and transport cancellation. Use isolated test credentials and pasteboards. Exercise actual UI and key retrieval after restarting the signed app. Update docs, build/package and push the feature branch; preserve the published v1.0.0 release.

The user additionally requested select text → § and a local classifier before processing. Read selected text through Accessibility on that explicit action; Spanish uses Apple's English translation and eligible Dutch uses OpenRouter. A confirmed empty selection uses the clipboard. Permission, secure-field and unsupported-selection errors show visible guidance without using unrelated clipboard content. Keep the explicit clipboard menu commands and automatic Spanish copy behavior.

Local development signing uses an existing personal Apple Development certificate to preserve the app identity and Accessibility grant across updates. The local certificate choice stays in ignored configuration; CI retains its ad-hoc default.
