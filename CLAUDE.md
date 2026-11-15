# CLAUDE.md

This file documents the posture-checker codebase for Claude Code and collaborators.

## UI

UI work happens on the `UI` branch, independent of the backend (camera capture + posture detection), which lives separately. The UI consumes a `PostureState` and renders against it — it never talks to the camera directly.

### Project structure

Built as a Swift Package (not an `.xcodeproj`) so the project stays diff-friendly in git. Opens in Xcode directly via `Package.swift`, or builds/runs from the command line.

```
Package.swift
Resources/Info.plist          # bundle metadata, LSUIElement, camera usage string
Sources/PostureChecker/
  main.swift                  # entry point (NSApplication.shared.run())
  AppDelegate.swift           # status bar item, popover, overlay + onboarding window wiring
  SettingsView.swift          # menu bar popover content
  OnboardingView.swift        # first-launch welcome/benefits/controls/character-pick flow
  OnboardingWindowController.swift # normal titled window hosting OnboardingView
  CharacterCatalog.swift      # CharacterOption catalog (placeholder emoji previews)
  CharacterPickerView.swift   # shared character grid picker (onboarding + settings)
  PostureState.swift          # PostureState enum + PostureSource protocol + MockPostureSource
  CharacterOverlayView.swift  # the character, walk-on/walk-off/yell/red-flash logic
  OverlayWindowController.swift # transparent, click-through, full-screen overlay NSWindow
  CameraPermission.swift      # AVCaptureDevice permission request/redirect helper
scripts/run.sh                 # builds and launches as a real .app bundle
```

### How to run

```bash
./scripts/run.sh
```

This builds via `swift build` and manually assembles `build/PostureChecker.app` (copies the binary + `Resources/Info.plist`), then opens it. Running the raw binary with `swift run` works for logic but won't correctly exercise `LSUIElement` (hides Dock icon) or the camera permission prompt, since those come from the bundle's `Info.plist` — always test through `scripts/run.sh` or Xcode's Run, not `swift run` directly.

### Current state (skeleton, no real detection yet)

- **Menu bar only.** `NSApp.setActivationPolicy(.accessory)` in `AppDelegate` hides the Dock icon; an `NSStatusItem` with a SF Symbol (`figure.seated.side`) sits in the menu bar.
- **Onboarding** (`OnboardingView.swift` + `OnboardingWindowController.swift`): shown automatically on first launch (gated by `UserDefaults` key `hasCompletedOnboarding`), and re-openable anytime from the settings popover ("Show Welcome Guide Again"). A normal titled/closable window (not the click-through overlay), four pages:
  1. Welcome / what the app does and why it's worth leaving on
  2. How it works (on-device camera processing, calibration)
  3. Controls explained in plain language — menu bar icon, Recalibrate, Sensitivity, Pause, Quit
  4. Character picker (see below)
  Finishing sets the `hasCompletedOnboarding` flag and closes the window; the app underneath is already running (status item + overlay), so onboarding never blocks functionality.
- **Settings popover** (`SettingsView.swift`), opened by clicking the status item: camera picker (placeholder list, not wired to real devices yet), sensitivity slider (maps to "alert after N seconds slouched"), pause toggle, character picker, recalibrate button (no-op stub, has a `.help()` tooltip), "Show Welcome Guide Again", quit button. Also shows a "Grant Camera Access" prompt if not yet authorized, using `CameraPermission`.
- **Character catalog** (`CharacterCatalog.swift`) + **picker** (`CharacterPickerView.swift`): a small catalog of `CharacterOption` (id, name, blurb, emoji `preview`). The picker is a tappable grid, shared between onboarding and settings, writing the selection to `@AppStorage("selectedCharacterID")`. **Previews are emoji placeholders** — swap `CharacterOption.preview` for real asset/image references once the detailed pixel-art sprites (with shadows) are ready; nothing else about the picker UI needs to change.
- **Overlay window** (`OverlayWindowController.swift`): a borderless, transparent, click-through (`ignoresMouseEvents = true`), full-screen `NSWindow` at `.statusBar` level, present on all Spaces. Hosts the SwiftUI character view.
  - **Gotcha fixed:** `NSHostingView` sizes to its SwiftUI content's ideal size by default, not the window's frame — left unset, it collapsed into AppKit's coordinate origin (bottom-left) instead of covering the screen. Fixed by explicitly setting `contentView.frame = window.contentLayoutRect` and `autoresizingMask = [.width, .height]` when the window is built.
- **Character view** (`CharacterOverlayView.swift`): anchored to the **top-right corner** (`ZStack(alignment: .topTrailing)` + `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)`), walks on/off by sliding past the right edge. Reads the selected character from `CharacterCatalog` via `@AppStorage`. State machine driven by `PostureState`:
  - `.good` → character slides off past the right edge (nothing visible)
  - `.slouching(seconds:)` → character slides in to rest near the top-right corner
  - `.alert` → character stays, "sit up!" label appears, full-screen red flash fades in
  No audio yet — hook up `AVAudioPlayer` here when character "yells" is designed.
- **Posture state source** (`PostureState.swift`): `PostureState` enum (`.good`, `.slouching(seconds:)`, `.alert`) and a `PostureSource` protocol (`statePublisher: AnyPublisher<PostureState, Never>`). `MockPostureSource` cycles through the states once a second (good → slouching, ramping up to 10s → alert → back to good) purely so the UI can be built and demoed before the backend exists. **Swap `MockPostureSource` for the real posture-detection backend by making it conform to `PostureSource` and wiring it in in `AppDelegate.setUpOverlay()`** — that's the entire integration point between UI and backend.
- **Camera permission** (`CameraPermission.swift`): wraps `AVCaptureDevice.requestAccess(for: .video)`, and on denial opens System Settings' Camera privacy pane directly. Requested from `SettingsView.onAppear`. The UI only requests/surfaces this; actual camera capture is the backend's responsibility.

### Known gaps / next steps for UI

- Character previews are emoji placeholders; needs real detailed pixel-art sprites (with shadows) once style is decided (open question in the main `README.md`) — only `CharacterOption.preview` needs to change.
- No audio yet for the "yell" state.
- Camera picker in settings is a static placeholder list, not backed by real `AVCaptureDevice.DiscoverySession` results.
- Onboarding's "How it works" / "Controls" copy will need a pass once calibration UX is actually built by the backend side.
