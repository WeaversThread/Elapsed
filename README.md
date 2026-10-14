# Elapsed

A Dieter Rams–inspired menu bar timer for macOS. Dark glass, Helvetica Neue Thin numerals, nothing extra.

## Features

- **Menu bar capsule.** Left-click opens the timer, right-click starts or pauses it.
- **Bar slider and presets.** Drag the bars or click a preset, then press play.
- **Type a time.** Click the big time (or drag past the end of the slider) and type `90`, `1:30`, `1h30` or `45m`.
- **Count down to a clock time.** Type `@14:30`, `@2:30pm` or `at 9` and it runs until then.
- **Overtime and snooze.** After a timer ends it counts up (`+0:42`) so you know how late you are; `+5` gives you five more minutes.
- **Playlists.** Sequences of focus and rest segments (Pomodoro and friends), with optional auto-advance and repeat.
- **Floating window.** A resizable glass window that stays above everything else and remembers where you put it.
- **Survives restarts.** A running or paused timer picks up where it left off after a quit, crash or update.
- **Settings** (gear icon or ⌘,): your own presets, slider range, focus and rest colors, three menu bar styles, alarm sound, volume and length, notifications, launch at login, and global shortcuts.

## Keyboard

In the timer popover:

| Key | Action |
|-----|--------|
| Space | Start, pause, resume (stop when finished) |
| ← / → | One minute less / more (⇧ for five) |
| 1–9 | Pick a preset |
| ⌘, | Settings |
| ⌘Q | Quit |

Global shortcuts for start/pause, open and stop can be recorded in Settings › General. They need no Accessibility permission.

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
| `elapsed://pause`, `elapsed://resume`, `elapsed://stop` | Just that |
| `elapsed://snooze` | A few more minutes after a timer ends |
| `elapsed://next` | Skip to the next playlist segment |
| `elapsed://playlist?name=Pomodoro` | Start a playlist |
| `elapsed://open`, `elapsed://window`, `elapsed://settings` | Show the popover, floating window or settings |

## Install

Download `Elapsed-<version>.zip` from [Releases](https://github.com/WeaversThread/Elapsed/releases), unzip it and move `Elapsed.app` to `/Applications`.

The app is ad-hoc signed, not notarized, so macOS blocks the first launch. Right-click the app and choose **Open**, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/Elapsed.app
```

## Build from source

Requires macOS 15+ and Swift 6. The Command Line Tools are enough; Xcode isn't needed.

```bash
bash build.sh --install
```

`build.sh` builds `build/Elapsed.app`. `--install` replaces `/Applications/Elapsed.app` and relaunches it, `--zip` also writes a release zip. With only the Command Line Tools installed, the script builds against the macOS 26 SDK, because the CLT don't ship the SwiftUI macro plugin the macOS 27 SDK needs.

## License

MIT
