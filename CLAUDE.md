# CLAUDE.md

This file documents the posture-checker codebase for Claude Code and collaborators. The app is named **Apollo** (god associated with good physique) — repo/folder name stayed `posture-checker`, but the product, bundle, and all in-app copy say Apollo.

## Repo history note

UI and backend were built independently on separate branches (`UI` and `main`) and merged on 2026-11-15. The backend had its own `PostureChecker.xcodeproj` with a minimal `MenuBarExtra` + debug-panel UI of its own — that harness (`PostureChecker/PostureCheckerApp.swift`, `CameraPreviewView.swift`, `DebugPanelView.swift`, and the `.xcodeproj` itself) was **deleted** after the merge, per explicit user direction to keep Apollo's UI and fold the backend's actual detection logic into it. Nothing about that decision reflects badly on the backend code — `PostureCore` and the camera/detection pieces are untouched logic, just relocated and wired into Apollo's own app shell instead of the collaborator's.

## Project structure

One Swift Package at the repo root (`Apollo`, in `Sources/Apollo/`) depending on a second local package (`PostureCore`) for the actual posture-detection logic. No `.xcodeproj` — stays diff-friendly in git, opens in Xcode directly via `Package.swift`, or builds/runs from the command line.

```
Package.swift                  # target "Apollo", depends on local PostureCore package, macOS 14 minimum
Resources/Info.plist           # bundle metadata, LSUIElement, camera usage string
Resources/Apollo.entitlements  # App Sandbox + camera entitlement — for later code-signed distribution, unused by scripts/run.sh's unsigned dev build
Sources/Apollo/
  main.swift                   # entry point (NSApplication.shared.run())
  AppDelegate.swift             # status bar item, popover, overlay + onboarding window wiring
  Theme.swift                   # black/grey/white palette — no system accent color anywhere
  SettingsView.swift             # menu bar popover content
  OnboardingView.swift          # first-launch welcome/proof/how-it-works/controls/character-pick flow
  OnboardingWindowController.swift # normal titled dark window hosting OnboardingView
  CharacterCatalog.swift        # CharacterOption catalog (placeholder emoji previews)
  CharacterPickerView.swift     # shared character grid picker (onboarding + settings)
  PostureState.swift            # PostureState enum + PostureSource protocol + MockPostureSource
  CharacterOverlayView.swift    # the character, walk-on/walk-off/yell logic
  OverlayWindowController.swift # transparent, click-through, full-screen overlay NSWindow
  CameraPermission.swift        # just the "open System Settings" redirect now
  SubscriptionManager.swift     # StoreKit 2 entitlement/purchase/restore, no backend
  PaywallView.swift             # subscribe sheet shown from settings
  CameraManager.swift           # REAL backend: owns the AVCaptureSession, device discovery/selection
  PoseDetector.swift            # REAL backend: Vision-based face/body detection per frame
  SceneSampler.swift            # REAL backend: background-change signature, feeds auto-recalibration
  PostureMonitor.swift          # REAL backend: "the one object the UI needs" — ties camera+detection+engine together, publishes slouchLevel/distanceLevel/calibration/etc.
  PostureMonitorAdapter.swift   # the only UI-side code touching the backend: extension PostureMonitor: PostureSource
scripts/run.sh                  # builds and launches as a real .app bundle
Resources/Apollo.storekit       # local StoreKit test config (see Subscription section)
PostureCore/                    # separate local Swift package: pure detection logic, no camera/Vision/UI code, has its own test suite
  Sources/PostureCore/{Assessment,Baseline,PoseSample,PostureEngine,SceneChange,SustainedTracker}.swift
  Tests/PostureCoreTests/PostureCoreTests.swift   # 41 tests, run with `cd PostureCore && swift test` — no camera needed
```

### How to run

```bash
./scripts/run.sh
```

This builds via `swift build` and manually assembles `build/Apollo.app` (copies the binary + `Resources/Info.plist`), then opens it. Running the raw binary with `swift run` works for logic but won't correctly exercise `LSUIElement` (hides Dock icon) or the camera permission prompt, since those come from the bundle's `Info.plist` — always test through `scripts/run.sh` or Xcode's Run, not `swift run` directly.

To re-trigger onboarding during testing: `defaults delete com.apollo.posture hasCompletedOnboarding`, or use the "SHOW ONBOARDING AGAIN" button in settings.

To test the detection engine in isolation (no camera, no app): `cd PostureCore && swift test`.

## The UI/backend integration point

**`PostureSource`** (in `PostureState.swift`) is the entire contract:

```swift
protocol PostureSource: AnyObject {
    var statePublisher: AnyPublisher<PostureState, Never> { get }
    var isPaused: Bool { get }
    func setPaused(_ paused: Bool)
    var sensitivity: Double { get set }   // 1 = default, 0.25...4, higher = more sensitive
}
```

This shape was deliberately changed to match **`PostureMonitor`'s real, already-existing API** (read-only `isPaused` + `setPaused()` method, a continuous `sensitivity` scale) rather than forcing the backend to contort itself to fit a mock-era shape (the original version had a settable `isPaused` and a `slouchThresholdSeconds: TimeInterval`, which assumed a seconds-based alert delay the real engine doesn't actually use — `PostureEngine`/`SustainedTracker` in `PostureCore` already encode their own warn/alarm timing).

- **`PostureMonitorAdapter.swift`** is the only file that bridges the two sides: `PostureMonitor` already has everything (`isPaused`, `setPaused`, `sensitivity`), so the adapter just adds `statePublisher`, combining `$slouchLevel` and `$distanceLevel` (`AlertLevel.ok/.warning/.alarm` from `PostureCore`) into our `PostureState.good/.slouching/.alert` via `max(slouch, distance)`.
- **`AppDelegate`** holds `private var postureSource = PostureMonitor()` — the real backend, used by default. `PostureMonitor.init()` starts its own camera, so there's no separate `.start()` call in `applicationDidFinishLaunching` anymore.
- **`MockPostureSource`** still exists, conforms to the same (now-adjusted) protocol, and is kept specifically for UI-only iteration without a working camera pipeline. To use it: change `AppDelegate`'s `postureSource` type back to `MockPostureSource`, and the two `@ObservedObject var postureSource: PostureMonitor` declarations (in `SettingsView` and `AppDelegate`'s private `CharacterOverlayHostView`) back to `MockPostureSource`. This isn't wired as a runtime toggle on purpose — it's a manual swap for whoever is doing pure UI work, not a shipped feature.

## Backend integration details, by piece

- **Camera picker** (`SettingsView`): no longer a UI-owned placeholder. Binds directly to `postureSource.camera.devices` / `.selectedDeviceID` / `.select(deviceID:)` — `CameraManager` (the real object) owns device discovery, persistence (its own `UserDefaults` key, `preferredCameraID`), and permission requesting. The earlier placeholder `CameraCatalog.swift` and `CameraPermission.request()` are gone; `CameraPermission.swift` now only has `openSystemSettings()`, used when `postureSource.camera.authorization == .denied`.
- **Sensitivity slider**: binds directly to `postureSource.sensitivity` (`Slider(value: $postureSource.sensitivity, in: 0.25...4, step: 0.25)`). No more "alert after Ns slouched" framing — that was never how the real engine worked; it has its own fixed warn/alarm timing (`SustainedTracker.Timing.slouch` = 8s warn / 12s alarm) and `sensitivity` instead scales how far from baseline counts as bad (`Thresholds(sensitivity:)` in `PostureCore/Assessment.swift`).
- **Pause toggle**: `Toggle(isOn: Binding(get: { postureSource.isPaused }, set: { postureSource.setPaused($0) }))` — can't bind directly since `isPaused` is read-only on the real object (pausing also does real work: stops the camera, resets tracking state).
- **Recalibrate button**: now calls `postureSource.startCalibration()` for real (previously a no-op stub). Settings also shows a live `postureSource.statusText` line underneath it ("Calibrating. Hold still.", "Posture looks good", "Can't see anyone", etc.) — this directly answers the README's original "no help or fine-tuning" fix-item for Nekoze's complaints.
- **`PostureState.slouching(seconds:)`** associated value is effectively unused now (the adapter always passes `0`) since the real engine doesn't expose "how many seconds into the slouch" — only the three discrete `AlertLevel` states. Left in the enum since `CharacterOverlayView` doesn't render the seconds anywhere visible; removing the associated value isn't worth the churn unless something actually needs it later.
- **Platform bumped macOS 13 → 14** in `Package.swift`: `CameraManager`'s `AVCaptureDevice.DiscoverySession` uses `.external` and `.continuityCamera` device types, which need macOS 14. Matches the backend's original Xcode project deployment target exactly.
- **`Resources/Apollo.entitlements`** (App Sandbox + camera device entitlement) came from the backend's Xcode project. Not used by the current unsigned `scripts/run.sh` dev build — only matters once the app is code-signed for real distribution.
- **`.gitignore`** merged from both branches (adds `DerivedData/`, `xcuserdata/` on top of what Apollo's side already had).

## Visual language

Strictly **black / grey / white** — no blue system accent anywhere — and deliberately **pixelated/retro**, to match the pixel-art character sprites that will eventually replace the emoji placeholders. Defined centrally in `Theme.swift`:
- Colors: `background`, `surface`, `surfaceSelected`, `textPrimary`, `textSecondary`, `divider`, `accent`.
- `Theme.pixelFont(size:weight:)` — currently `.system(design: .monospaced)`, **not a real bitmap pixel font yet**. No licensed pixel font file (e.g. "Press Start 2P") is bundled. If/when one is added, drop the font file into `Resources/` and change this one function to `.custom(name, size:)` — every call site picks it up automatically.
- `PixelPanel` view modifier + `.pixelPanel()` — square-cornered double-outline panel, used instead of rounded rectangles/capsules (pixel art doesn't do soft corners or blur).
- `PixelButtonStyle` — blocky solid-fill button with a hard border, press state just nudges down 2px instead of easing.
Onboarding, settings, and the paywall all use `Theme.pixelFont` for text and `PixelButtonStyle`/`pixelPanel()` for chrome, and force `.preferredColorScheme(.dark)` / `NSAppearance(named: .darkAqua)` so they stay dark regardless of system appearance. Any new UI should pull from `Theme`, not hardcode `.gray`/`.blue`/`Color.accentColor`/rounded corners/system fonts.

## UI pieces

- **Menu bar only.** `NSApp.setActivationPolicy(.accessory)` in `AppDelegate` hides the Dock icon; an `NSStatusItem` with the SF Symbol `figure.stand` (a person standing upright, i.e. good posture) sits in the menu bar. The app's actual icon/logo (Dock/Finder artwork) is still undecided — not set yet. (`PostureMonitor.menuBarSymbol` has its own richer SF Symbol logic — `pause.circle`, `questionmark.circle`, `figure.walk`, `exclamationmark.triangle(.fill)` — not wired into the status item yet; currently it's a fixed icon regardless of state. Worth doing as a follow-up.)
- **Onboarding** (`OnboardingView.swift` + `OnboardingWindowController.swift`): shown automatically on first launch (gated by `UserDefaults` key `hasCompletedOnboarding`), and re-openable anytime from settings ("SHOW ONBOARDING AGAIN" box). A normal titled/closable dark window (not the click-through overlay), five pages:
  1. **Welcome** — emotionally-pitched intro to Apollo and the name
  2. **Why it matters** — the "proof" page. Written from real (if mixed) research rather than invented stats: upright sitting is linked to better mood/lower fatigue than slouching, and posture has been shown to affect memory recall in some studies, but the page is explicit that the posture→focus research itself is mixed — framed as "small free win," not a miracle claim. Sources used while writing this copy: [NIH – Influence of Posture on Attention](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10102972/), [NIH – Effect of Body Posture on Cognitive Performance](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3973903/), [Slouching and Mental Health](https://total-wellness.squarespace.com/articles/slouching-and-feeling-slumped-how-posture-can-affect-your-mental-health). **Do not replace this with fabricated statistics or invented studies** — if stronger claims are wanted later, find a real citation first.
  3. **How it works** — on-device camera processing, calibration
  4. **Controls** explained in plain language — menu bar icon, Recalibrate, Sensitivity, Pause, Quit
  5. **Character picker** (see below)
  Finishing sets the `hasCompletedOnboarding` flag and closes the window; the app underneath is already running (status item + overlay), so onboarding never blocks functionality. All onboarding copy avoids em dashes on purpose (short sentences instead) so it doesn't read as AI-generated — keep that style for any future onboarding copy. Progress indicator is a glowing fill bar (`progressBar` in `OnboardingView`), not dots: a square `Rectangle` track with a white `Rectangle` fill sized to `(page + 1) / pageCount`, double `.shadow()` for the glow, animated on page change.
  - `OnboardingView` takes `startPage` and `finalButtonLabel` (defaults `0` / `"GET STARTED"`), and exposes `static let characterPageIndex = 4`. This lets the exact same screen be reused for two different entry points from settings, rather than building separate UI for each (see below).
- **Settings popover** (`SettingsView.swift`): camera picker, sensitivity slider, pause toggle (all wired to the real `postureSource` now — see integration section above), a "CHANGE CHARACTER" box, "RECALIBRATE" + live status text, "SHOW ONBOARDING AGAIN" box, quit button — all as square pixel-style buttons via `PixelButtonStyle`, not plain text links. Shows a "Grant Camera Access" prompt when `postureSource.camera.authorization != .authorized`. Forced dark appearance to match the theme.
- **Character selection flow**: settings doesn't embed the character grid inline. The "CHANGE CHARACTER" box (shows the current character's emoji + name) calls `AppDelegate.showCharacterPicker()`, which opens `OnboardingWindowController(startPage: OnboardingView.characterPageIndex, title: "Choose Your Character", finalButtonLabel: "DONE")` — literally the same character-picker screen from onboarding, just opened straight to that page. Picking a character and pressing "DONE" closes the window and drops you back to normal, same as finishing onboarding does. "SHOW ONBOARDING AGAIN" reuses the same window at `startPage: 0` with `finalButtonLabel: "DONE"` (not "GET STARTED," since it's a replay, not first run) — `AppDelegate.showOnboarding()` picks the label based on whether `hasCompletedOnboarding` is already true.
- **Character catalog** (`CharacterCatalog.swift`) + **picker** (`CharacterPickerView.swift`): a catalog of `CharacterOption` (id, name, blurb, emoji `preview`, `quote`). The picker is a tappable scrolling grid (`ScrollView` + `LazyVGrid`, capped with a `maxHeight` parameter), shared between onboarding and the character-change window, writing the selection to `@AppStorage("selectedCharacterID")`. **Roster (13 characters — Greek mythology + a fixed set of historical figures, per explicit user direction):** Apollo (default) ☀️, Zeus ⚡, Athena 🦉, Aphrodite 🌹, Poseidon 🔱, Hades 🔥, Agamemnon 🛡️, Medusa 🐍, Satyr 🐐, Benjamin Franklin 💵, Napoleon 🎩, Alexander the Great 🐎, Genghis Khan 🐎.
  - **Each character has its own `quote`**, shown in the overlay's `.alert` label instead of a generic "SIT UP!" — e.g. Napoleon: "NOT TONIGHT. SIT UP, SOLDIER.", Zeus: "STRAIGHTEN UP OR I STRIKE." Add a `quote` for any character added later — `CharacterOverlayView` reads it directly, no fallback text exists.
  - **The roster was trimmed from an earlier 20-character version** (which also included Pablo Escobar, Gordon Ramsay, Wreck-It Ralph, The Godfather, Donald Trump, Vladimir Putin, and "The Soldier"). That trim was the user's own direction, not a legal workaround, but it does incidentally resolve the legal/policy flags that version carried (Trump/Putin real-person right-of-publicity risk, Wreck-It Ralph being Disney IP, Nazi-adjacent imagery risk on "The Soldier"). If any of those ever get added back, re-read those flags before commissioning real art for them.
  - **Previews are emoji placeholders** — swap `CharacterOption.preview` for real asset/image references once the detailed pixel-art sprites (with shadows) are ready; nothing else about the picker UI needs to change. Deliberately built this way so dropping in real art later is a one-line-per-character change, not a rework.
- **Overlay window** (`OverlayWindowController.swift`): a borderless, transparent, click-through (`ignoresMouseEvents = true`), full-screen `NSWindow` at `.statusBar` level, present on all Spaces. Hosts the SwiftUI character view.
  - **Gotcha fixed:** `NSHostingView` sizes to its SwiftUI content's ideal size by default, not the window's frame — left unset, it collapsed into AppKit's coordinate origin (bottom-left) instead of covering the screen. Fixed by explicitly setting `contentView.frame = window.contentLayoutRect` and `autoresizingMask = [.width, .height]` when the window is built.
- **Character view** (`CharacterOverlayView.swift`): anchored to the **top-right corner** (`ZStack(alignment: .topTrailing)` + `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)`), walks on/off by sliding past the right edge. Reads the selected character from `CharacterCatalog` via `@AppStorage`. State machine driven by `PostureState`:
  - `.good` → character slides off past the right edge (nothing visible)
  - `.slouching(seconds:)` → character slides in to rest near the top-right corner
  - `.alert` → character stays, the selected character's `quote` label appears (no red screen flash — removed per user request, felt too jarring)
  No audio yet — hook up `AVAudioPlayer` here when character "yells" is designed.

## Subscription (StoreKit 2, no backend server)

Mac-only, so this is entirely native: Apple ties entitlement to the user's Apple ID, no account system or database of ours involved. (Unrelated to the camera/detection backend — "backend" here just means "no server.")

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
- Nothing is gated behind the subscription yet (no feature currently checks `isSubscribed`) — this is infrastructure only, ready for whichever feature ends up being the paid one.

## Known gaps / next steps

- Character previews are emoji placeholders; needs real detailed pixel-art sprites (with shadows) once style is decided — only `CharacterOption.preview` needs to change.
- No real pixel/bitmap font bundled yet — `Theme.pixelFont` is a monospaced system-font stand-in. Swap in a licensed pixel font file when one is chosen.
- No audio yet for the "yell" state.
- Menu bar icon is fixed; `PostureMonitor.menuBarSymbol` already computes a state-appropriate SF Symbol that isn't wired into `AppDelegate`'s status item yet.
- Onboarding's "How it works" / "Controls" copy could tighten up now that the real calibration UX exists (it was written generically, ahead of the backend landing — it already holds up reasonably well, but worth a pass).
- Main `README.md` still refers to the app generically in places — worth a pass to adopt the Apollo name throughout now that UI and backend are one codebase.
- `PostureCore`'s test suite (41 tests) only covers the pure logic layer (no camera). There's no test coverage yet for `PostureMonitor`/`CameraManager`/`PoseDetector` themselves, or for the new UI-side `PostureMonitorAdapter`.
- `Resources/Apollo.entitlements` exists but isn't used by the current unsigned dev build — only relevant once code-signing for real distribution.
