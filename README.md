# Elapsed

A Dieter Rams–inspired menu bar timer for macOS. Dark glass, Helvetica Neue Thin numerals, nothing extra.

## Features

- **Menu bar capsule.** Left-click opens the timer, right-click starts or pauses it. Follows a light or dark menu bar.
- **Bar slider and presets.** Drag the bars or click a preset, then press play.
- **Type a time.** Click the big time (or drag past the end of the slider) and type `90`, `1:30`, `1h30` or `45m`.
- **Count down to a clock time.** Type `@14:30`, `@2:30pm` or `at 9` and it runs until then.
- **Overtime and snooze.** After a timer ends it counts up (`+0:42`, for up to an hour) so you know how late you are; `+5` gives you five more minutes.
- **Playlists.** Sequences of focus and rest segments (Pomodoro and friends), with optional auto-advance and repeat.
- **Floating window.** A resizable glass window that stays above everything else and remembers where you put it.
- **Survives restarts.** A running or paused timer picks up where it left off after a quit, crash or update.
- **Settings** (gear icon or ⌘,): your own presets, focus and rest colors, two menu bar styles, alarm sound, volume and length, notifications, launch at login and global shortcuts.
- **Light on the battery.** No polling: it wakes once a second while counting down (not at all while the screen is off), and uses no CPU when idle.

## Keyboard

In the timer popover:

| Key | Action |
|-----|--------|
| Space | Start, pause, resume (stop when finished) |
| ← / → | One minute less / more (⇧ for five) |
| 1–9 | Pick a preset |
| ⌘, | Settings |
| ⌘Q | Quit |

Global shortcuts for start/pause, open and stop can be recorded in Settings › General. They work from any app and need no Accessibility permission.

## URL scheme

Works from Shortcuts, Raycast, Alfred, Stream Deck or the terminal:

```bash
open "elapsed://start?min=25"
```

| URL | Action |
|-----|--------|
| `elapsed://start` | Start with the current time |
| `elapsed://start?min=25` | Start a 25-minute timer (`min` also takes `1:30`, `1h30`) |
| `elapsed://start?until=14:30` | Count down to 14:30 |
| `elapsed://toggle` | Start, pause or resume |
| `elapsed://stop` | Stop |
| `elapsed://snooze` | A few more minutes after a timer ends |
| `elapsed://playlist?name=Pomodoro` | Start a playlist |

## Install

Download `Elapsed-<version>.dmg` from [Releases](https://github.com/WeaversThread/Elapsed/releases), open it and drag Elapsed to Applications. It runs on Apple silicon and Intel Macs with macOS 15 or later.

Unless the release says it's notarized, macOS blocks the first launch. Right-click the app and choose **Open**, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/Elapsed.app
```

## Build from source

Requires macOS 15+ and Swift 6. The Command Line Tools are enough; Xcode isn't needed.

```bash
bash build.sh --install
```

| Command | Result |
|---------|--------|
| `bash build.sh` | `build/Elapsed.app` for this Mac |
| `bash build.sh --install` | Same, then replaces `/Applications/Elapsed.app` and relaunches it |
| `bash build.sh --test` | Runs the tests |
| `bash build.sh --release` | For the web: a universal `build/Elapsed-<version>.dmg` and `.zip`. Signed with your Developer ID and notarized if the certificate is in your keychain, ad-hoc signed otherwise |
| `bash build.sh --appstore` | For the Mac App Store: a universal, sandboxed `build/Elapsed-<version>.pkg` to upload with Transporter |

With only the Command Line Tools installed, the script builds against the macOS 26 SDK, because the CLT don't ship the SwiftUI macro plugin the macOS 27 SDK needs.

### Signing for distribution

Both notarized web builds and App Store builds need a paid [Apple Developer](https://developer.apple.com/programs/) account.

- **Web (notarized):** create a *Developer ID Application* certificate, then save notarization credentials once with `xcrun notarytool store-credentials elapsed-notary`. `--release` then signs, notarizes and staples.
- **Mac App Store:** register the bundle ID `com.endurance.Elapsed`, create an *Apple Distribution* and a *Mac Installer Distribution* certificate and a Mac App Store provisioning profile, and save the profile as `Elapsed.provisionprofile` in the repo folder (it's git-ignored). `--appstore` signs with the sandbox entitlements and builds the `.pkg`. Raise `CFBundleVersion` in `StatusTimer/Info.plist` for every upload.

## License

MIT
