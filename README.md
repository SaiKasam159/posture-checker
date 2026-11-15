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

## Build order

1. Menu bar app skeleton with camera picker and live preview.
2. Posture detection with calibration and a slouch score.
3. Slouch timer and the overlay layer, with a placeholder character.
4. Real character art and animation, then the yell and red flash.
5. Onboarding.

## Open questions

- Who are the characters, and what's the art style?
- Is front-on detection accurate enough across setups (external monitors, off-centre cameras, low light)? Step 2 answers this.
- Ship through the Mac App Store, as a direct download, or both?
