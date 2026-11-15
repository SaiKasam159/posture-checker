# CLAUDE.md

This file documents the posture-checker codebase for Claude Code and collaborators. The app is named **Apollo** (god associated with good physique) — repo/folder name stayed `posture-checker`, but the product, bundle, and all in-app copy say Apollo.

## UI

UI work happens on the `UI` branch, independent of the backend (camera capture + posture detection), which lives separately. The UI consumes a `PostureState` and renders against it — it never talks to the camera directly.

### Project structure

Built as a Swift Package (not an `.xcodeproj`) so the project stays diff-friendly in git. Opens in Xcode directly via `Package.swift`, or builds/runs from the command line.

```
Package.swift                  # target name "Apollo"
Resources/Info.plist          # bundle metadata, LSUIElement, camera usage string
Sources/Apollo/
  main.swift                  # entry point (NSApplication.shared.run())
  AppDelegate.swift           # status bar item, popover, overlay + onboarding window wiring
  Theme.swift                 # black/grey/white palette — no system accent color anywhere
  SettingsView.swift          # menu bar popover content
  OnboardingView.swift        # first-launch welcome/proof/how-it-works/controls/character-pick flow
  OnboardingWindowController.swift # normal titled dark window hosting OnboardingView
  CharacterCatalog.swift      # CharacterOption catalog (placeholder emoji previews)
  CharacterPickerView.swift   # shared character grid picker (onboarding + settings)
  PostureState.swift          # PostureState enum + PostureSource protocol + MockPostureSource
  CharacterOverlayView.swift  # the character, walk-on/walk-off/yell/red-flash logic
  OverlayWindowController.swift # transparent, click-through, full-screen overlay NSWindow
  CameraPermission.swift      # AVCaptureDevice permission request/redirect helper
  CameraCatalog.swift         # real connected-camera enumeration for the settings picker
  SubscriptionManager.swift   # StoreKit 2 entitlement/purchase/restore, no backend
  PaywallView.swift           # subscribe sheet shown from settings
scripts/run.sh                 # builds and launches as a real .app bundle
Resources/Apollo.storekit      # local StoreKit test config (see Subscription section)
```

### How to run

```bash
./scripts/run.sh
```

This builds via `swift build` and manually assembles `build/Apollo.app` (copies the binary + `Resources/Info.plist`), then opens it. Running the raw binary with `swift run` works for logic but won't correctly exercise `LSUIElement` (hides Dock icon) or the camera permission prompt, since those come from the bundle's `Info.plist` — always test through `scripts/run.sh` or Xcode's Run, not `swift run` directly.

To re-trigger onboarding during testing: `defaults delete com.apollo.posture hasCompletedOnboarding`, or use the "Show Welcome Guide Again" button in settings.

### Visual language

Strictly **black / grey / white** — no blue system accent anywhere — and deliberately **pixelated/retro**, to match the pixel-art character sprites that will eventually replace the emoji placeholders. Defined centrally in `Theme.swift`:
- Colors: `background`, `surface`, `surfaceSelected`, `textPrimary`, `textSecondary`, `divider`, `accent`.
- `Theme.pixelFont(size:weight:)` — currently `.system(design: .monospaced)`, **not a real bitmap pixel font yet**. No licensed pixel font file (e.g. "Press Start 2P") is bundled. If/when one is added, drop the font file into `Resources/` and change this one function to `.custom(name, size:)` — every call site picks it up automatically.
- `PixelPanel` view modifier + `.pixelPanel()` — square-cornered double-outline panel, used instead of rounded rectangles/capsules (pixel art doesn't do soft corners or blur).
- `PixelButtonStyle` — blocky solid-fill button with a hard border, press state just nudges down 2px instead of easing.
Onboarding, settings, and the paywall all use `Theme.pixelFont` for text and `PixelButtonStyle`/`pixelPanel()` for chrome, and force `.preferredColorScheme(.dark)` / `NSAppearance(named: .darkAqua)` so they stay dark regardless of system appearance. Any new UI should pull from `Theme`, not hardcode `.gray`/`.blue`/`Color.accentColor`/rounded corners/system fonts.

### Current state (skeleton, no real detection yet)

- **Menu bar only.** `NSApp.setActivationPolicy(.accessory)` in `AppDelegate` hides the Dock icon; an `NSStatusItem` with the SF Symbol `figure.stand` (a person standing upright, i.e. good posture) sits in the menu bar. The app's actual icon/logo (Dock/Finder artwork) is still undecided — not set yet.
- **Onboarding** (`OnboardingView.swift` + `OnboardingWindowController.swift`): shown automatically on first launch (gated by `UserDefaults` key `hasCompletedOnboarding`), and re-openable anytime from settings ("SHOW ONBOARDING AGAIN" box). A normal titled/closable dark window (not the click-through overlay), five pages:
  1. **Welcome** — emotionally-pitched intro to Apollo and the name
  2. **Why it matters** — the "proof" page. Written from real (if mixed) research rather than invented stats: upright sitting is linked to better mood/lower fatigue than slouching, and posture has been shown to affect memory recall in some studies, but the page is explicit that the posture→focus research itself is mixed — framed as "small free win," not a miracle claim. Sources used while writing this copy: [NIH – Influence of Posture on Attention](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10102972/), [NIH – Effect of Body Posture on Cognitive Performance](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3973903/), [Slouching and Mental Health](https://total-wellness.squarespace.com/articles/slouching-and-feeling-slumped-how-posture-can-affect-your-mental-health). **Do not replace this with fabricated statistics or invented studies** — if stronger claims are wanted later, find a real citation first.
  3. **How it works** — on-device camera processing, calibration
  4. **Controls** explained in plain language — menu bar icon, Recalibrate, Sensitivity, Pause, Quit
  5. **Character picker** (see below)
  Finishing sets the `hasCompletedOnboarding` flag and closes the window; the app underneath is already running (status item + overlay), so onboarding never blocks functionality. All onboarding copy avoids em dashes on purpose (short sentences instead) so it doesn't read as AI-generated — keep that style for any future onboarding copy. Progress indicator is a glowing fill bar (`progressBar` in `OnboardingView`), not dots: a square `Rectangle` track with a white `Rectangle` fill sized to `(page + 1) / pageCount`, double `.shadow()` for the glow, animated on page change.
  - `OnboardingView` now takes `startPage` and `finalButtonLabel` (defaults `0` / `"GET STARTED"`), and exposes `static let characterPageIndex = 4`. This lets the exact same screen be reused for two different entry points from settings, rather than building separate UI for each (see below).
- **Settings popover** (`SettingsView.swift`), opened by clicking the status item: real camera picker (see `CameraCatalog` below), sensitivity slider and pause toggle **wired directly to `postureSource`** (not local throwaway state — see below), a "CHANGE CHARACTER" box, "RECALIBRATE" (still a no-op stub, needs the backend's calibration routine), "SHOW ONBOARDING AGAIN" box, quit button — all as square pixel-style buttons via `PixelButtonStyle`, not plain text links. Also shows a "Grant Camera Access" prompt if not yet authorized, using `CameraPermission`. Forced dark appearance to match the theme.
- **Character selection flow**: settings no longer embeds the character grid inline. Instead, the "CHANGE CHARACTER" box (shows the current character's emoji + name) calls `AppDelegate.showCharacterPicker()`, which opens `OnboardingWindowController(startPage: OnboardingView.characterPageIndex, title: "Choose Your Character", finalButtonLabel: "DONE")` — literally the same character-picker screen from onboarding, just opened straight to that page. Picking a character and pressing "DONE" closes the window and drops you back to normal, same as finishing onboarding does. "SHOW ONBOARDING AGAIN" reuses the same window at `startPage: 0` with `finalButtonLabel: "DONE"` (not "GET STARTED," since it's a replay, not first run) — `AppDelegate.showOnboarding()` picks the label based on whether `hasCompletedOnboarding` is already true.
- **Camera picker is real** (`CameraCatalog.swift`): enumerates actually-connected cameras via `AVCaptureDevice.devices(for: .video)` (the newer `DiscoverySession` with `.external` needs macOS 14, above our macOS 13 minimum, so this deliberately uses the deprecated-but-functional API — one compiler warning, expected). The selected device's `uniqueID` is persisted to `UserDefaults` under `CameraCatalog.selectedCameraIDKey` ("selectedCameraUniqueID"). **This is the integration contract with the backend**: the UI only lists devices and remembers the choice, the backend should read this same key to know which camera to actually open for capture.
- **Pause/sensitivity are real, not cosmetic**: `PostureSource` protocol (in `PostureState.swift`) now requires `isPaused: Bool` and `slouchThresholdSeconds: TimeInterval`, both settable. `MockPostureSource` persists both to `UserDefaults` (`monitoringPaused`, `slouchThresholdSeconds`) so they survive relaunch, and its timer actually respects them (`tick()` early-returns while paused, compares elapsed slouch time against the threshold instead of a hardcoded `10`). Settings' Toggle/Slider bind directly to `postureSource.isPaused` / `postureSource.slouchThresholdSeconds` via `@ObservedObject`, no separate local `@State` copy to keep in sync. **When the real backend replaces `MockPostureSource`, it must also implement these two properties** — that's as much a part of the `PostureSource` contract as `statePublisher` now.
- **Character catalog** (`CharacterCatalog.swift`) + **picker** (`CharacterPickerView.swift`): a catalog of `CharacterOption` (id, name, blurb, emoji `preview`, **`quote`**). The picker is a tappable scrolling grid (`ScrollView` + `LazyVGrid`, capped with a `maxHeight` parameter), shared between onboarding and the character-change window, writing the selection to `@AppStorage("selectedCharacterID")`. **Roster (13 characters — Greek mythology + a fixed set of historical figures, per explicit user direction):** Apollo (default) ☀️, Zeus ⚡, Athena 🦉, Aphrodite 🌹, Poseidon 🔱, Hades 🔥, Agamemnon 🛡️, Medusa 🐍, Satyr 🐐, Benjamin Franklin 💵, Napoleon 🎩, Alexander the Great 🐎, Genghis Khan 🐎.
  - **Each character has its own `quote`**, shown in the overlay's `.alert` label instead of a generic "SIT UP!" — e.g. Napoleon: "NOT TONIGHT. SIT UP, SOLDIER.", Zeus: "STRAIGHTEN UP OR I STRIKE." Add a `quote` for any character added later — `CharacterOverlayView` reads it directly, no fallback text exists.
  - **The roster was trimmed from an earlier 20-character version** (which also included Pablo Escobar, Gordon Ramsay, Wreck-It Ralph, The Godfather, Donald Trump, Vladimir Putin, and "The Soldier"). That trim was the user's own direction, not a legal workaround, but it does incidentally resolve the legal/policy flags that version carried (Trump/Putin real-person right-of-publicity risk, Wreck-It Ralph being Disney IP, Nazi-adjacent imagery risk on "The Soldier"). If any of those ever get added back, re-read those flags before commissioning real art for them.
  - **Previews are emoji placeholders** — swap `CharacterOption.preview` for real asset/image references once the detailed pixel-art sprites (with shadows) are ready; nothing else about the picker UI needs to change. Deliberately built this way so dropping in real art later is a one-line-per-character change, not a rework.
- **Overlay window** (`OverlayWindowController.swift`): a borderless, transparent, click-through (`ignoresMouseEvents = true`), full-screen `NSWindow` at `.statusBar` level, present on all Spaces. Hosts the SwiftUI character view.
  - **Gotcha fixed:** `NSHostingView` sizes to its SwiftUI content's ideal size by default, not the window's frame — left unset, it collapsed into AppKit's coordinate origin (bottom-left) instead of covering the screen. Fixed by explicitly setting `contentView.frame = window.contentLayoutRect` and `autoresizingMask = [.width, .height]` when the window is built.
- **Character view** (`CharacterOverlayView.swift`): anchored to the **top-right corner** (`ZStack(alignment: .topTrailing)` + `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)`), walks on/off by sliding past the right edge. Reads the selected character from `CharacterCatalog` via `@AppStorage`. State machine driven by `PostureState`:
  - `.good` → character slides off past the right edge (nothing visible)
  - `.slouching(seconds:)` → character slides in to rest near the top-right corner
  - `.alert` → character stays, the selected character's `quote` label appears, full-screen red flash fades in
  No audio yet — hook up `AVAudioPlayer` here when character "yells" is designed.
- **Posture state source** (`PostureState.swift`): `PostureState` enum (`.good`, `.slouching(seconds:)`, `.alert`) and a `PostureSource` protocol (`statePublisher`, `isPaused`, `slouchThresholdSeconds` — see above). `MockPostureSource` cycles through the states once a second (good → slouching, ramping up to the configured threshold → alert → back to good) purely so the UI can be built and demoed before the backend exists. **Swap `MockPostureSource` for the real posture-detection backend by making it conform to `PostureSource` (including the pause/sensitivity properties) and wiring it in in `AppDelegate.setUpOverlay()`** — that's the entire integration point between UI and backend.
- **Camera permission** (`CameraPermission.swift`): wraps `AVCaptureDevice.requestAccess(for: .video)`, and on denial opens System Settings' Camera privacy pane directly. Requested from `SettingsView.onAppear`. The UI only requests/surfaces this; actual camera capture is the backend's responsibility.

### Subscription (StoreKit 2, no backend)

Mac-only, so this is entirely native: Apple ties entitlement to the user's Apple ID, no account system or database of ours involved.

- **`SubscriptionManager.swift`** (`@MainActor`, `ObservableObject`): owns everything.
  - `Self.productID = "com.apollo.posture.monthly"` — must match a subscription product created in App Store Connect (for real shipping) or the local `Resources/Apollo.storekit` config (for development testing).
  - `isSubscribed` is derived purely from `Transaction.currentEntitlements` — this *is* the entire "is the user subscribed" check, no server round-trip.
  - `purchase()` drives Apple's native purchase sheet via `Product.purchase()`.
  - `restore()` calls `AppStore.sync()` for "I subscribed on another device" / "let me double-check" cases.
  - Listens to `Transaction.updates` continuously so renewals/cancellations/refunds update `isSubscribed` live.
  - Owned by `AppDelegate` (created inside `applicationDidFinishLaunching`, not as a stored-property initializer, to dodge a `@MainActor` initializer-isolation build error) and passed into `SettingsView`.
- **`PaywallView.swift`**: sheet shown from settings' "Subscribe" button. Shows price (from the real `Product`, not hardcoded), a Subscribe CTA, and Restore Purchases.
- **Settings subscription section**: status row (green dot + "Apollo Premium active", or "Not subscribed"), and either a "Subscribe" button (opens the paywall) or a "Manage Subscription" button.
  - **"Manage Subscription" does not open a sheet we build.** SwiftUI's `.manageSubscriptionsSheet(isPresented:)` modifier is iOS-only and fails to compile on macOS. On macOS the standard pattern is `SubscriptionManager.openManageSubscriptions()`, which just opens `https://apps.apple.com/account/subscriptions` in the browser. Apple's own page handles cancellation, plan changes, and billing problems entirely. **This is the answer to "is there even a need to manage it": barely.** We only need to surface status and link out; we never build cancel/upgrade/billing UI ourselves.
- **`Resources/Apollo.storekit`**: a local StoreKit configuration file so purchases can be tested without App Store Connect set up yet. To use it, open the package in Xcode, edit the run scheme's Options tab, and set "StoreKit Configuration" to this file — then `purchase()` runs against sandboxed fake transactions. Without this wired up (e.g. running via `scripts/run.sh`), `Product.products(for:)` will return nothing and the paywall will show "Subscription unavailable right now," which is expected until either the scheme is configured or a real product exists in App Store Connect.

### Known gaps / next steps for UI

- Character previews are emoji placeholders; needs real detailed pixel-art sprites (with shadows) once style is decided — only `CharacterOption.preview` needs to change.
- No real pixel/bitmap font bundled yet — `Theme.pixelFont` is a monospaced system-font stand-in. Swap in a licensed pixel font file when one is chosen.
- No audio yet for the "yell" state.
- Recalibrate button is still a no-op stub, needs the backend's calibration routine.
- Onboarding's "How it works" / "Controls" copy will need a pass once calibration UX is actually built by the backend side.
- Main `README.md` (shared with backend) still refers to the app generically — worth a joint pass to adopt the Apollo name project-wide rather than just in the UI code.
- Nothing is gated behind the subscription yet (no feature currently checks `isSubscribed`) — subscription infrastructure is built and working, just not attached to any paid feature.
