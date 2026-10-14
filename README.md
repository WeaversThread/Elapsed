# Elapsed

A Dieter Rams–inspired menu bar timer for macOS. Dark glass, Helvetica Neue Thin numerals, nothing extra.

- Left-click the menu bar capsule to open the timer, right-click to start or pause
- Drag the bar slider or pick a preset, then press play
- Playlists run a sequence of focus and rest segments (Pomodoro and friends)
- A floating window shows the countdown above everything else

## Build

Requires macOS 15+ and the Swift 6 toolchain (Command Line Tools are enough, no Xcode needed).

```bash
bash build.sh
cp -r build/Elapsed.app /Applications/
```
