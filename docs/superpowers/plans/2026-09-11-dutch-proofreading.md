# Dutch proofreading implementation plan

The user requested Dutch sentence/email corrections, excluding code and names, plus a toggle between minimal corrections and improved phrasing. The final trigger decision is shortcut-only, using the bare § key after copying; Spanish remains automatic. Both versions must be copyable. Earlier on-device processing and quiet clipboard behavior remain requirements.

## Design

Retain Apple's Spanish translation pipeline. Recognize Dutch locally with NaturalLanguage and conservative prose checks. Use the already-installed local Ollama runtime with qwen3.5:9b for two structured Dutch outputs: corrected and improved. Connect only to 127.0.0.1. No cloud endpoint or clipboard history is added. The optional Dutch feature has its own Setup toggle and readiness check; its runtime/model requirement is explained in Setup and README.

One shared card presents either Spanish translation or Dutch proofreading. Dutch defaults to Corrected and offers a segmented Improved phrasing option. Copy uses the currently selected text and resets its confirmation on selection changes. The five-second countdown, hover pause, stale-result cancellation, confidential markers, and clipboard preservation apply to both modes. An unavailable Dutch model produces a recoverable Setup message, without preventing Spanish translation.

## Work

- [x] Add failing Dutch eligibility tests for sentences, emails, typos, emoji, names, code, fragments, other languages and limits. Implement the detector.
- [x] Add a local proofreading client with a fixed loopback endpoint, structured response parsing, bounded output, cancellation and clear errors. Test request boundaries and decoding; manually evaluate real Dutch examples using the downloaded model.
- [x] Add shared card state and test minimal/improved selection, the text selected for copying, and cancellation. Integrate the Dutch task without opening Apple's TranslationSession for Dutch.
- [x] Add independent Dutch settings, readiness, demo, the global § shortcut and a matching menu command. A manual clipboard snapshot consumes the pending monitor event to avoid immediate cancellation. Preserve pause/suspension and Spanish behavior.
- [x] Build and test; inspect both card variants, copy behavior, code/name suppression and recovery in the running app. Review before integrating.
- [x] Update README and verification notes. Keep the published 1.0.0 release unchanged while this feature is evaluated locally.
