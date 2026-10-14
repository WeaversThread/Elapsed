# Elapsed Design System Brief

A reference for building future macOS apps in the same Dieter Rams-inspired dark glass aesthetic.

---

## Philosophy

**Less but better.** Every element earns its place. No decoration, no chrome, no gradients. Controls appear when needed (hover) and disappear when not. Typography does the heavy lifting. Animation communicates state, not personality.

Rams' ten principles distilled for software:
- **Useful** — the app does one thing and the UI never gets in the way
- **Unobtrusive** — lives in the menu bar, floats when summoned, vanishes when dismissed
- **Honest** — no skeuomorphism, no fake depth, just glass and light
- **Long-lasting** — neutral palette that won't age, system-native behaviors
- **Thorough** — every state has a visual, every transition has motion

---

## Color System

All colors are white at varying opacities on dark glass. The only hue is functional: one accent for focus, one for rest. The user picks each from a curated set of swatches (red, Braun orange, yellow, green, teal, blue, violet, white) — never a free color picker. Defaults are red and blue.

### Opacity Scale

| Token | Value | Usage |
|-------|-------|-------|
| `primary` | `white @ 0.85` | Time display, active capsule fill, stop button text |
| `secondary` | `white @ 0.7` | Continue button text |
| `tertiary` | `white @ 0.45` | Control labels (cancel, pause, restart) |
| `quaternary` | `white @ 0.35` | Preset labels (inactive), segment labels, playlist names |
| `muted` | `white @ 0.25` | Utility icons (window, gear), settings icons |
| `subtle` | `white @ 0.12` | Borders, unfilled slider bars |
| `surface` | `white @ 0.08` | Dividers, button backgrounds, input backgrounds |
| `surface-dim` | `white @ 0.06` | Playlist item backgrounds, section backgrounds |
| `surface-faint` | `white @ 0.04` | Nested element backgrounds |

### Functional Colors

| Color | Value | Usage |
|-------|-------|-------|
| Focus | `focusAccent @ 0.7` (fill), `@ 0.15` (shadow) | Running slider bars, time glow, progress capsule |
| Rest | `restAccent @ 0.6` (fill), `@ 0.15` (shadow) | Rest segment slider, time glow |
| Finished | `white @ 0.2` (shadow) | Completion glow on 0:00 |

### Status Bar States

Two styles, chosen in Settings › Look. Idle is the same outline in both. Colors follow the menu bar: the values below are for a dark menu bar; on a light one, white and black swap (idle stroke `white(0.3)`, text `white(0.15)`, running fill `black @ 0.8` with white text).

**Capsule** (default)

| State | Fill | Text |
|-------|------|------|
| Idle | Stroke `white(0.7) @ 0.5`, 1px | `white(0.85)` |
| Running | Fill `white @ 0.85` | `white(0.08)` (dark) |
| Paused | Blink `white @ 0.3` / `white @ 0.5` | `white(0.08)` (dark) |
| Finished | Fill `white @ 0.85` | `white(0.08)` (dark), shows "+0:42" overtime or "0:00" |

**Progress** — track `ink @ 0.18`; the accent (`@ 0.8`) fills left to right as time elapses; paused blinks the fill; finished is fully filled. The text flips where the fill passes: `ink @ 0.95` over the track, white over the accent (dark over yellow or white accents).

---

## Typography

Two fonts only. Helvetica Neue Thin for numerals (the Braun clock face). SF Pro for everything else.

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Status bar time | SF Mono | 11 | medium (active) / regular (idle) |
| Popover time display | HelveticaNeue-Thin | 36 | thin |
| Active timer time | HelveticaNeue-Thin | 42 | thin |
| Window time | HelveticaNeue-Thin | dynamic* | thin |
| Control labels | SF Pro | 13 | regular |
| Preset buttons | SF Pro | 11 | semibold (selected) / regular |
| Playlist names | SF Pro | 10 | regular |
| Segment labels | SF Pro | 11 | regular |
| Utility labels | SF Pro | 10-11 | regular |
| Settings tabs | SF Pro | 12 | semibold (selected) / regular |
| Settings section titles | SF Pro | 11 | medium |
| Settings row labels | SF Pro | 12 | regular |
| Settings details / footers | SF Pro | 10 | regular |
| Settings fields | SF Pro | 11-12 | regular/medium |

*Window time scales: `min(width * 0.35, height * 0.45)` for running, `min(width * 0.3, height * 0.35)` for finished.

All numeric displays use `.monospacedDigit()` to prevent layout jitter.

---

## Animation

### Principles
- **Spring for interaction** — buttons, state changes, transitions
- **Linear for data** — countdown ticks
- **EaseInOut for ambient** — hover reveals, pause blink
- **No animation during drag** — slider tracks finger directly

### Parameters

| Context | Type | Duration | Bounce |
|---------|------|----------|--------|
| Button press / state change | Spring | 0.2-0.25s | 0 |
| Hover scale+brightness | Spring | 0.2s | 0.3 |
| Popover state transition | Spring | 0.3s | 0 |
| Slider bar grow effect | Spring | 0.3s | 0.15 |
| Window hover controls | Spring | 0.3s | 0.2 |
| Timer countdown tick | Linear | 0.1s | - |
| Pause breath | Sine, 15 fps | 2s period | 3 breaths, then a hard 1s step |
| Hover reveal (scrub, close) | EaseInOut | 0.15s | - |
| Popover open/close | None | instant | - |

### Transitions
- State changes: asymmetric opacity + slide (in from bottom, out to top)
- Finished state: opacity only
- Numeric text: `.numericText()` content transition
- Window controls: opacity + scale (0.85 -> 1.0)

---

## Spacing

### Grid
No formal grid. Spacing is contextual but consistent within components.

| Context | Value |
|---------|-------|
| Popover outer padding | H: 20, V: 16 |
| Settings outer padding | 18 all sides |
| Settings section spacing | 16 |
| Settings row padding | H: 10, V: 7 (min height 34) |
| Component internal spacing | 0 (VStack) with explicit spacers |
| Divider vertical margin | 10 |
| Button internal padding | H: 4-6, V: 2-4 |
| Settings section padding | H: 10, V: 6 |
| Settings segment padding | H: 8, V: 3 |
| Window top margin | 12 min |
| Window control bottom | 16 |

---

## Components

### Glass Background
```
VisualEffectBlur
  material: .hudWindow
  blendingMode: .behindWindow
  state: .active
  appearance: .darkAqua
```
Used on every surface — popover, settings window, floating window. Never a solid background.

### HoverButton
Scale: 1.0 -> 1.08, Brightness: 0 -> +0.15, Spring 0.2s bounce 0.3. Applied to every interactive element. No exceptions.

### Status Bar Capsule
Fixed frame: 72x22 (item), 68x18 (capsule). Monospaced, centered on the digits' cap height, shrinking in 0.5pt steps down to 6.5pt to fit. The icon never grows or shifts — only the text inside scales.

Drawn with Core Graphics and Core Text into an image (`StatusBarFace`), not SwiftUI: the menu bar re-snapshots the item on every change, and an image snapshots cheaply. It's redrawn only when what it shows changes, and the image draws on demand so each display's menu bar gets its own light or dark colors. No continuous animations in the menu bar — every frame costs a snapshot.

### Slider (Bar Array)
60 bars, 2px wide, corner radius 1. Height range: 8-24px. Grow effect: bars near the thumb position grow taller with `growRadius: 5`. No thumb dot — the bar heights ARE the indicator.

### Floating Window
Borderless + resizable. Custom close button (x icon, appears on hover). No titlebar, no traffic lights. Movable by background. Floats above all windows. Content clips to `RoundedRectangle(cornerRadius: 10)` with subtle border stroke.

### Glass Window
`GlassWindow`: borderless `NSWindow` subclass with `canBecomeKey = true` (so text fields take typing), clear background, dark appearance, ⌘W and Esc close it. The floating timer window (frame autosaved) and the settings window are both made by `GlassWindow.make`, both at `.floating` level.

### Settings Window
380×460 glass panel, rounded 10, `white @ 0.12` border, hover-revealed close button top-left. A text tab row (Timer · Playlists · Look · Sound · General): selected `white @ 0.85` semibold, others `white @ 0.35`. Changes apply immediately — no Save, no Cancel. Floats above other windows, since there's no Dock icon to bring it back. Labels explain themselves; hint text is a last resort (one footer, for `@14:30`).

Building blocks:
- **SettingsSection** — title, then rows on `white @ 0.06` rounded 6, optional footer `white @ 0.3`
- **SettingsRow** — label left, control right; hairline dividers `white @ 0.06`
- **GlassSwitch** — 28×16 capsule, `white @ 0.12` off / `white @ 0.7` on, knob inverts
- **GlassChoice** — text options in a capsule, selected on `white @ 0.14`
- **GlassStepper** — − value + with circular `white @ 0.08` buttons
- **SwatchPicker** — 14pt accent circles, selected ringed `white @ 0.85`
- **VolumeBars** — a rising wedge of 24 bars, the slider's language at small scale
- **PresetEditor** — 30pt capsule chips you type into, × on hover, + to add (3–9)

### Scrub Bar
Vertical, 6px wide, 40px tall. Track: 1px `white @ 0.08`. Thumb: 3px wide rounded rect, `white @ 0.35`, appears on hover. Maps drag position to scroll target.

---

## Sizes

| Element | Width | Height |
|---------|-------|--------|
| Status bar item | 72 | 22 |
| Popover | 320 | 190 |
| Settings window | 380 | 460 |
| Timer window (initial) | 280 | 160 |
| Timer window (minimum) | 200 | 120 |
| Play button | 30 | 30 |
| Utility icon buttons | 20 | 20 |
| Preset buttons | flex | 28 min |
| Finished stop button | 80-110 | 34-42 |
| Playlist carousel | 80 max | 44 max |

---

## Corner Radii

| Element | Radius |
|---------|--------|
| Window frame | 10 |
| Playlist section (settings) | 6 |
| Playlist items, input fields | 4 |
| Settings segment rows | 3 |
| Scrub bar thumb | 2 |
| Slider bars | 1 |
| Buttons (capsule) | Capsule() |
| Play button | Circle() |

---

## Architecture (for code consistency)

### State Management
- Single `ObservableObject` engine, `@MainActor`
- `@Published` for all reactive state
- No polling: one precise timer fires at the end; a 1s display tick lines up with the second boundaries (Date-based, not decrement). App Nap is held off only while counting down
- Display ticks stop while the screens sleep or the session is inactive; the end timer keeps running
- Overtime ticks at 1s without holding off App Nap, and stops after an hour
- The popover's content exists only while it's open; closed windows are released
- Callbacks (closures) for cross-layer communication (engine -> AppDelegate)

### Persistence
- `UserDefaultsStore`: `@MainActor ObservableObject` singleton, injected with `.environmentObject` at every hosting root
- `@Published` `prefs` (`prefs_v1`), `playlists` (`playlists_v2`), `lastUsedMinutes`; `snapshot_v1` holds a running or paused timer
- JSON encoding for complex types; every field decodes with `decodeIfPresent` and a default, so new fields never wipe saved data

### App Structure
- LSUIElement (no dock icon)
- NSStatusItem with an image drawn by `StatusItemController` for the status bar
- NSPopover (transient, no animation) for menu
- NSWindow (borderless, floating) for desktop view
- SMAppService for login item, toggled in Settings (never registered automatically)
- Carbon `RegisterEventHotKey` for global shortcuts (no Accessibility permission)
- `elapsed://` URL scheme for automation

### Build
- Swift Package Manager, no Xcode project
- Shell script creates .app bundle manually and ad-hoc signs it
- Resources copied via SPM `.copy()` directive
- Info.plist copied from `StatusTimer/Info.plist` (literal values, no variable expansion)
- With only the Command Line Tools, build against the macOS 26 SDK (the CLT lack the SwiftUI macro plugin for the 27 SDK)

---

## Anti-Patterns (What NOT to Do)

- No solid backgrounds — always glass
- No system controls in windows — custom everything
- No dock icon, no menu bar menu (right-click is for timer toggle)
- No confirmation dialogs — actions are immediate and reversible
- No tooltips — the UI is self-evident or it's wrong
- No color outside the two functional accents (focus, rest)
- No font outside Helvetica Neue Thin + SF Pro
- No animation slower than 0.3s (except ambient blink)
- No hover effects below 1.08x scale — it must be perceptible
- Never grow the status bar icon — shrink the text instead
