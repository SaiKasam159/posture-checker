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
  AppDelegate.swift           # status bar item, popover, overlay window wiring
  SettingsView.swift          # menu bar popover content
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
- **Settings popover** (`SettingsView.swift`), opened by clicking the status item: camera picker (placeholder list, not wired to real devices yet), sensitivity slider (maps to "alert after N seconds slouched"), pause toggle, recalibrate button (no-op stub), quit button. Also shows a "Grant Camera Access" prompt if not yet authorized, using `CameraPermission`.
- **Overlay window** (`OverlayWindowController.swift`): a borderless, transparent, click-through (`ignoresMouseEvents = true`), full-screen `NSWindow` at `.statusBar` level, present on all Spaces. Hosts the SwiftUI character view. Nothing on it intercepts clicks — it's purely visual.
- **Character view** (`CharacterOverlayView.swift`): placeholder emoji character (swap for real art later). State machine driven by `PostureState`:
  - `.good` → character animates off-screen (nothing visible)
  - `.slouching(seconds:)` → character animates on-screen
  - `.alert` → character stays on-screen, "sit up!" label appears, red screen flash overlay fades in
  No audio yet — hook up `AVAudioPlayer` here when character "yells" is designed.
- **Posture state source** (`PostureState.swift`): `PostureState` enum (`.good`, `.slouching(seconds:)`, `.alert`) and a `PostureSource` protocol (`statePublisher: AnyPublisher<PostureState, Never>`). `MockPostureSource` cycles through the states once a second (good → slouching, ramping up to 10s → alert → back to good) purely so the UI can be built and demoed before the backend exists. **Swap `MockPostureSource` for the real posture-detection backend by making it conform to `PostureSource` and wiring it in in `AppDelegate.setUpOverlay()`** — that's the entire integration point between UI and backend.
- **Camera permission** (`CameraPermission.swift`): wraps `AVCaptureDevice.requestAccess(for: .video)`, and on denial opens System Settings' Camera privacy pane directly. Requested from `SettingsView.onAppear`. The UI only requests/surfaces this; actual camera capture is the backend's responsibility.

### Known gaps / next steps for UI

- Character is a placeholder emoji; needs real art once style is decided (open question in the main `README.md`).
- No audio yet for the "yell" state.
- Camera picker in settings is a static placeholder list, not backed by real `AVCaptureDevice.DiscoverySession` results.
- Onboarding screen (per `README.md` build order) not started.
