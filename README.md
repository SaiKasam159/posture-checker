# posture-checker

A native Mac app that watches your posture through the webcam while you work. When you slouch, a character walks onto your screen. Sit up and it walks away. Stay slouched and it yells at you and the screen flashes red.

## Decisions so far

- **Mac only, native (Swift + SwiftUI).** No Windows, no phone app for now.
- **Laptop/desktop webcam, not a phone.** The camera already faces the user, the app can run in the background, and the characters appear on the screen the user is looking at.
- **The phone idea (prop up the phone, lock your apps) is parked.** A side view would detect slouching more accurately, but iOS doesn't allow background camera use and app locking needs Apple's Screen Time entitlement. It is closer to a separate focus app and could be a later version.
- **Goal for now: a good demo app.** Beat Nekoze (the closest competitor, a Mac app where a cat meows when you slouch) on reliability and polish, with characters people actually like.

## Why this could work

People turn posture apps off once the nagging gets annoying. The characters are our answer to that, so they need the most care. If they're charming, people keep the app running and share clips of it.

## What Nekoze gets wrong, and our fix

Taken from Nekoze's App Store reviews (raw text in [`Issues`](Issues)). The pattern across all of them is that the app fails silently: it never shows what it sees or why it's reacting.

| Complaint | Our fix |
|---|---|
| Can't choose a camera; it only uses the laptop one, so an external-monitor setup alerts constantly | Camera picker in settings, remembered per setup |
| Assumes you sit facing the laptop | Calibrate against the user's own normal sitting position, at whatever angle the camera sees them; recalibrate in one click |
| Can't find the user in good light; glasses break it | Track head and shoulders with Apple's built-in body and face tracking instead of relying on the face alone |
| Constant meows unrelated to posture | Only alert after a sustained slouch (say 10+ seconds), with a sensitivity slider |
| Cat images pop up with no explanation | Short onboarding that shows each character state and what it means |
| Start button can't be pressed; stuck at calibration | Calibration shows a live preview and says why it's blocked ("can't see your shoulders", "too dark") |
| No help or fine-tuning | Live preview with the posture score, so the user can see what the app sees |

## How it should feel

Like Granola: it runs in the background and stays out of the way.

- **Menu bar only.** A small icon in the top bar, no Dock icon, no main window.
- **Invisible until needed.** Characters live in a transparent, click-through layer above the user's work. Nothing is on screen while posture is good.
- **Small settings popover** from the menu bar icon: camera, sensitivity, pause, recalibrate.
- **Light on battery.** Check posture once or twice a second, not at full video rate.
- **Private.** All video is processed on the device and never leaves it. The green camera light stays on while tracking, so the app needs a visible pause button and a clear privacy statement.

## Character behaviour

1. Posture is good: nothing on screen.
2. Slouched for a set number of seconds: a character walks on.
3. User corrects their posture: the character walks away.
4. User stays slouched: the character yells and the screen flashes red.

## Running it

Needs Xcode 16 or later and macOS 14 or later.

1. Open `PostureChecker.xcodeproj` and press Run. There is no Dock icon; look for the icon in the menu bar.
2. Allow camera access. This is the only permission the app asks for.
3. Click the menu bar icon, sit up straight at arm's length from the screen, and press **Calibrate**.

The logic tests run without a camera: `cd PostureCore && swift test`.

## How detection works

Each camera keeps its own calibration, so everything is judged against how *you* sit in front of *that* camera.

**Slouching** is any of these moving too far from the calibrated position:

- the shoulder line tilting (leaning to one side)
- the head sinking toward the shoulders (hunching forward)
- the head dropping in the frame (sliding down in the chair)

Only the face is required. If the shoulders are hidden (a hoodie, a tight camera angle), the first two checks are skipped and the app tracks the head alone.

**Too close** is the face appearing about 1.3 times wider than at calibration, which is roughly a quarter closer to the screen.

**Moving the laptop** recalibrates automatically. The app keeps a small picture of the background with the person blanked out. If most of that background changes and then holds still for 2 seconds, the camera has moved, so it relearns the user's position and says so. A person moving, a TV, or the lights changing don't count, because they change only part of the background or only its brightness. It can't tell against a blank wall, and it assumes the user is sitting normally right after the move. Manual recalibration is always there. This logic is in `SceneChange.swift`.

Neither fires straight away. Slouching must last 8 seconds before the warning and a further 12 before the alarm. Being too close must last 15 seconds before the warning and a further 15 before the alarm, so leaning in to read something is ignored. Two seconds back in a good position clears either one.

All these numbers are first guesses and need tuning on real setups. They live in `PostureCore/Sources/PostureCore/Assessment.swift` (how far) and `SustainedTracker.swift` (how long).

## Code layout

- `PostureCore/` holds the posture logic as a Swift package with no camera code, so it can be unit tested.
- `PostureChecker/` is the app: camera (`CameraManager`), landmark detection (`PoseDetector`) and `PostureMonitor`, which ties them together.
- `PostureChecker/DebugPanelView.swift` is a plain test panel, there to be replaced by the real UI.

### For the UI and characters

Everything the UI needs is published by `PostureMonitor`:

- `slouchLevel` and `distanceLevel` are each `.ok`, `.warning` or `.alarm`. `.warning` means the character walks on, `.alarm` means it yells, and back to `.ok` means it walks away.
- `assessment.slouchReason` says what kind of slouch it is, if the characters should react differently.
- `personPresent`, `isCalibrated`, `calibration` and `statusText` cover the remaining states.

## Build order

1. ~~Menu bar app skeleton with camera picker and live preview.~~ Done.
2. ~~Posture detection with calibration and a slouch score.~~ Built, needs tuning on real setups.
3. The overlay layer, with a placeholder character. (The slouch timer is done.)
4. Real character art and animation, then the yell and red flash.
5. Onboarding.

## Open questions

- Who are the characters, and what's the art style?
- Is front-on detection accurate enough across setups (external monitors, off-centre cameras, low light)? Step 2 answers this.
- Ship through the Mac App Store, as a direct download, or both?
