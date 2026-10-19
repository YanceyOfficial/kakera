# CLAUDE.md — Kakera (欠片)

Kakera — Japanese for "fragment": each flashcard is a small piece of knowledge that adds up
to a whole language. Formerly "Kai" (甲斐); renamed because the name was taken on the App Store.
Native Apple rewrite of the Kai flashcard app for memorizing difficult vocabulary,
in English and Japanese (one deck per language, switched in the app). SwiftUI + SwiftData + Swift Charts, on-device AI
(Claude/OpenAI), FSRS spaced repetition. iPhone first; Watch/Mac/TV later.

## Layout

- Organized per the **Tuist standard template** (`tuist init`): `Project.swift` + `Tuist.swift` + `Tuist/Package.swift`. The Xcode project/workspace are generated (`tuist generate`), not committed.
- `kakera/` — the app target (`Kakera`, product module `Kakera`, bundle `app.yancey.kakera`, Swift 6, iOS 17+). Uses Tuist `buildableFolders`: `kakera/Sources` (app code), `kakera/Resources` (assets), `kakera/Tests`.
- `Packages/` — local Swift packages (the kernel; no UI):
  - `KakeraCore` — SwiftData models, enums, value types, `VocabularyRepository`, and `ReviewScheduler` (bridges the persisted `SchedulingState` to KakeraFSRS). **Synced through CloudKit** (`KakeraModelContainer.onDisk(cloudKitContainer:)`, private database of `iCloud.app.yancey.kakera`), so modeling stays CloudKit-safe: defaults/optionals, no relationships, no `@Attribute(.unique)`. Dedupe is in code: `VocabularyRepository.mergeDuplicates()` folds the twins sync creates (survivor = first-created, then smallest id — the same on every device — taking over the most-reviewed twin's schedule, logs, tags, notes); `RootView` runs it at launch and on `NSPersistentStoreRemoteChange`. Depends on KakeraFSRS.
  - `KakeraFSRS` — pure FSRS-6 spaced-repetition algorithm. Zero dependencies. Validated against ts-fsrs.
  - `KakeraAI` — `LLMProvider` protocol + Claude/OpenAI structured-output over `URLSession` (`HTTPTransport` is injectable). Produces Codable DTOs, not SwiftData. Depends on KakeraCore (enums only).
  - `KakeraServices` — logging (`os.Logger`), Keychain (`SecretStore`), FSRS-driven forgetting-push scheduling + quiet hours, Vision OCR, word pronunciation (`PronunciationVoice`: Youdao dictvoice via `AVPlayer` — English by `type`, Japanese by `le=jap`, said by its kana reading (`JapaneseSpeech`); whatever Youdao has no audio for, e.g. a Japanese sentence or no network, falls back to `AVSpeechSynthesizer`). Depends on KakeraFSRS. Pattern: **protocol + pure (tested) logic + thin platform adapter (compiled, not unit-tested)**.
  - `KakeraUI` — the design system (`KakeraColor`/`KakeraFont`/`KakeraSpacing`, `KakeraMotion` springs + gesture math, `FlipCard`, `KakeraMark`, toasts) and ruby: `Ruby` parses the inline furigana markup `{漢字|かんじ}` the AI writes into Japanese sentences (`plain` / `reading`), and `RubyText` shows reading text: a read-only **TextKit 2** `UITextView` (TextKit 1 ignores Core Text ruby), so the system lays out the furigana (overhang, kinsoku) and a long press selects any span for the system edit menu — Copy, Look Up, Translate, Writing Tools. The card back and word detail use it for all their reading text; `showsFurigana` off drops the readings. Tested with `swift test --package-path Packages/KakeraUI`.
- `kakera/UITests` — `KakeraUITests` (XCTest; Swift Testing can't drive an app): `ScreenshotTests` walks the screens in light and dark over the DEBUG-only demo deck (`DemoDeck`, `-demoDeck YES`). Run `scripts/screenshots.sh [simulator id]` → `screenshots/<name>.png` / `<name>-dark.png`, used by the README and the website. Never take them by hand.
- `website/` — the site at https://kakera.yancey.app (TanStack Start + Solid, from Hikki's site; standalone, `bun install` inside). `/privacy` is the App Store privacy policy — keep it true to what the app sends where. The home page plays Apple-style scroll scenes (pinned hero and tour driven by `--p` from `src/scroll.ts`, plus CSS scroll-driven `reveal`/`drift`/`slide-x`); only transform/opacity move, and `prefers-reduced-motion` gets a still layout. Screenshots: `(cd website && bun run shots ../screenshots)`.
- `docs/superpowers/` — design spec (`specs/`) and per-package TDD implementation plans (`plans/`).
- App icon: `kakera/Resources/AppIcon.icon`, an Icon Composer document (SVG layers + `icon.json`;
  Xcode 26 compiles Liquid Glass for iOS 26+ and flat PNGs for older iOS), plus the launch screen's
  `LaunchMark` (vector SVG) and `LaunchBackground` in `Assets.xcassets`. All generated —
  `swift scripts/generate_app_icon.swift kakera/Resources` — never edited by hand.
  The mark is a Tokiwa-green "sliced sun"; `KakeraMark` (KakeraUI) draws the same geometry in SwiftUI for
  onboarding, the widget and `LaunchSplash` (the launch sunrise, played over whatever the root shows
  first — onboarding replaces the tabs until it's done, so nothing plays behind it), so change the two together.

## Build / run / test

Requires Xcode 26.x + Tuist. Prefix commands with `export PATH="/opt/homebrew/bin:$PATH"` if needed.

```bash
# Generate the Xcode project (after cloning or editing Project.swift / packages)
tuist generate
# (for VSCode/SourceKit-LSP indexing) regenerate the build-server config afterward:
xcode-build-server config -workspace kakera.xcworkspace -scheme Kakera

# Build & run the app in the simulator (product is Kakera.app, bundle app.yancey.kakera)
xcodebuild build -workspace kakera.xcworkspace -scheme Kakera -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Testing rules (important)

- **Pure packages run on macOS via `swift test`** (fast, no simulator):
  ```bash
  swift test --package-path Packages/KakeraFSRS
  swift test --package-path Packages/KakeraAI
  swift test --package-path Packages/KakeraServices
  ```
- **KakeraCore (and any SwiftData test) MUST run on the iOS Simulator** — SwiftData `#Predicate`
  fetches SIGTRAP on the macOS test host. Run from the package directory, using the
  package's own scheme (independent of the Tuist workspace):
  ```bash
  (cd Packages/KakeraCore && xcodebuild test -scheme KakeraCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro')
  ```
  All SwiftData tests live in ONE `@Suite(.serialized)` sharing a single in-memory
  `ModelContainer` (concurrent container creation crashes SwiftData). See
  `Packages/KakeraCore/Tests/KakeraCoreTests/SwiftDataTests.swift`.

## Conventions

- **App Store compliance:** `PrivacyInfo.xcprivacy` in the app and widget (UserDefaults reasons CA92.1 / 1C8F.1; no tracking, no collected data), `ITSAppUsesNonExemptEncryption = NO`, a Privacy Policy link in Settings, and the AI section says what is sent to Anthropic/OpenAI. Update them with any new API or data flow.
- **All code comments and user-facing app copy are in English.** (Design/plan docs may be Chinese.)
- **TDD** with **Swift Testing** (`import Testing` / `@Test("English label")` / `#expect`), not XCTest.
- Source/public declarations get English `///` doc comments; test functions self-document via `@Test` labels.
- API keys live in the Keychain (`KakeraServices.SecretStore`); never logged, never hardcoded, never committed.
- The AI layer talks to Claude (`claude-opus-4-8` default) and OpenAI via structured outputs;
  models are user-configurable in settings. No official Swift SDK — raw REST over `URLSession`.

## Status (2026-07)

Kernel green: KakeraCore (20 tests), KakeraFSRS (23), KakeraAI (18), KakeraServices (18). App green:
26 tests in `KakeraTests` (run on the simulator).

The app is a `MainTabView` shell — Review / Quiz / Words / Stats / Settings — over one
SwiftData store (a starter deck per language seeded at launch by `StarterSeed`).
**Languages:** `AppSettings.studyLanguage` (`@AppStorage("studyLanguage")`) picks the deck —
Settings → Language, or the menu under "Kakera" on the Review tab. `MainTabView` is keyed by it
(`.id`), so switching rebuilds every tab and each loads its own language's words; stores take
the language in `init` (tests pass it explicitly). Japanese cards reuse the English schema with
per-field meaning set by `PromptBuilder` (phonetic = kana reading + pitch accent `なつかしい ④`,
syllables = morae, roots = kanji breakdown) and ruby markup in every Japanese sentence;
`AICardMapper` strips markup from anything matched or compared (lemma, related words, quiz
answers). Quiz answers are kana-insensitive for Japanese. Neutral palette
with light/dark support (`KakeraColor` adaptive) and a Tokiwa green accent (常磐色,
`KakeraColor.accent`, #1B813E / #23A750 dark; `vermilion` is a legacy alias of it that app
views drop as they are redesigned). The "Again" rating is red (`KakeraColor.danger`).
- **Review** — `ReviewStore.load(newLimit:)` composes a session (up to N new words
  interleaved with due review words via `SessionComposer`); each rating reschedules
  through `ReviewScheduler`/FSRS, persists, and writes a `ReviewLog`. Flip card has
  haptics and auto-playing Youdao pronunciation. Finishing a group offers a chained quiz.
- **Quiz** — single-choice meaning quiz (`QuizGenerator` pure + `QuizStore`) that feeds
  FSRS (correct → good, wrong → again); also reachable as a follow-up to a review group.
- **Words** — searchable list + authoring (`AddWordsView`: single form, batch paste via
  `PastedWordsParser`, or **AI** generation via KakeraAI); swipe to delete.
- **Stats** — Swift Charts dashboard (`StatsAggregator` pure): counts, 7-day bars, accuracy.
- **Settings** — new-words-per-session, pronunciation accent/auto-play, and AI provider +
  API key (`AIConfigStore`, key stored in the Keychain). As in Exodus, a key is checked by
  fetching the provider's live model list (`KakeraAI.ModelListing`, Anthropic paged by
  `after_id`, OpenAI filtered to chat models); the model is picked from that list, and its
  own output ceiling (Anthropic's `max_tokens`) becomes the request's `max_tokens` — nothing
  is hardcoded: `AIConfigStore.readyConfiguration()` fetches the list first if the chosen
  model's ceiling is unknown, Claude without one fails with `noOutputLimit`, and OpenAI (whose
  list reports none) sends no `max_completion_tokens` at all. The AI layer is our own REST
  client: Anthropic's Swift package (ClaudeForFoundationModels) needs iOS 27 and is a
  Foundation Models provider, not a Messages client — revisit once iOS 27 ships. Requests
  are non-streaming, so they time out at 600 s, not URLSession's 60.

- **iCloud** — entitlements: CloudKit container, `aps-environment`, KVS (the starter deck is planted once per iCloud account: `starterSeeded.<language>` in `NSUbiquitousKeyValueStore`, only read while signed in). Settings → Sync shows the account status. Preferences stay per device. Before the first App Store release, deploy the CloudKit schema to Production in the CloudKit Console.

Next: share extension + OCR intake, more quiz types.
