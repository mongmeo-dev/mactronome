<p align="center">
  <img src="mactronome/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="128" height="128" alt="Mactronome icon">
</p>

<h1 align="center">Mactronome</h1>

<p align="center">
  <strong>A precise, low-latency metronome built natively for macOS.</strong>
</p>

<p align="center">
  <a href="https://github.com/mongmeo-dev/mactronome/releases/latest"><img src="https://img.shields.io/github/v/release/mongmeo-dev/mactronome?label=download&color=4f6bed" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-lightgrey?logo=apple" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" alt="Swift 6">
</p>

<p align="center">
  English | <a href="README.ko.md">한국어</a>
</p>

---

Mactronome is a metronome for musicians who care about timing. Every click is synthesized and scheduled directly on the audio thread, so what you hear lands exactly on the tempo you set — no drift, no lag on the first beat. It also has everything you need for daily practice: accent patterns, subdivisions, tempo trainer, polyrhythms, and presets.

> [!NOTE]
> The app interface is currently available in Korean only.

## Features

### 🎯 Accurate timing
- **Sample-accurate scheduling** — clicks are placed at the sample level on a real-time audio thread, not on UI timers.
- **Instant start** — the audio engine stays warm in the background, so the first click plays within milliseconds of pressing play.
- **Drift-free polyrhythms** — the secondary voice re-aligns to the main beat every bar.

### 🥁 Rhythm and accents
- **Tempo from 30 to 300 BPM**
- **Flexible time signatures** — 1 to 12 beats per bar, with 2, 4, 8, or 16 as the beat unit.
- **Subdivisions** — quarter, eighth, and sixteenth notes, plus triplets, quintuplets, and sextuplets.
- **Four accent levels per pulse** — strong, medium, weak, or mute. Click a bar to cycle through levels, or right-click to pick one directly.
- **Three click sounds** — Beep, Digital, and Clave.

### 🏋️ Practice tools
- **Tempo trainer** — automatically raises the tempo by a set amount every few bars until you reach your target BPM.
- **Count-in** — up to 8 bars of count-in before the metronome starts.
- **Polyrhythm** — layer a second voice on top of the main beat (e.g. 3 : 4).
- **Tap tempo** — tap along to find the tempo of a song.
- **Bar counter** — always know which bar you're on.
- **Presets** — save your BPM, time signature, accents, sound, and practice settings under a name, and recall them in one click.

### 🖥️ Built for the Mac
- **Menu bar control** — start, stop, and change the tempo from the menu bar without switching windows.
- **Compact mode** — shrink the window to a mini player that stays out of your way while you play.
- **Always on top** — keep the metronome visible over your sheet music or DAW.
- **Light and dark mode** — follows the system, or pick one yourself.
- **Visual flash** — see the beat as well as hear it. Flash rate is capped at 3 per second (WCAG 2.3.1) and softened when *Reduce Motion* is enabled.
- **Automatic updates** — new versions are delivered in-app.

## Installation

1. Download the latest `Mactronome-x.y.z.dmg` from the [Releases page](https://github.com/mongmeo-dev/mactronome/releases/latest).
2. Open the DMG and drag **Mactronome** into your **Applications** folder.
3. Launch Mactronome from Applications or Launchpad.

The app is signed and notarized by Apple, so it opens without any security warnings. After installation, you can check for updates at any time from **Mactronome → Check for Updates…**.

**Requirements:** macOS 14 Sonoma or later (Apple silicon and Intel)

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Start / Stop | `Space` or `⌘P` |
| BPM +10 / −10 | `↑` / `↓` (or `⌘↑` / `⌘↓`) |
| BPM +1 / −1 | `→` / `←` (or `⌘→` / `⌘←`) |
| Tap tempo | `⌘T` |
| Toggle compact mode | `⌘⇧C` |
| Open settings | `⌘,` |

You can also adjust the BPM by dragging or scrolling over the tempo display, or click it to type a value directly.

## Tips

- **Right-click an accent bar** to set its level directly instead of cycling through all four.
- **Click the speaker icon** to mute instantly; click again to restore the previous volume.
- Presets only store musical settings. Loading a preset won't change your appearance or window preferences.
- Sound, practice tools, and display options live in the **Settings** window (`⌘,`).

## Building from source

Mactronome is written in Swift 6 and SwiftUI with AVAudioEngine.

```bash
git clone https://github.com/mongmeo-dev/mactronome.git
cd mactronome
open mactronome.xcodeproj
```

Select the `mactronome` scheme and run it in Xcode. The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), so if you change the project structure, run `xcodegen generate` to regenerate it.

## Feedback

Found a bug or have an idea? Please [open an issue](https://github.com/mongmeo-dev/mactronome/issues).
