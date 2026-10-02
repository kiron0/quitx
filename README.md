<p align="center">
  <img src="Support/Icons/icon_256x256.png" width="96" height="96" alt="QuitX Icon" />
</p>

<h1 align="center">QuitX for macOS</h1>

<p align="center">
  <strong>A fresh start without a restart. Fast, minimal menubar app to quit, force quit, and manage running macOS apps.</strong>
</p>

<p align="center">
  <a href="https://github.com/kiron0/quitx/releases/latest"><img src="https://img.shields.io/github/v/release/kiron0/quitx?color=FFB800&label=Download%20QuitX&logo=apple" alt="Download QuitX" /></a>
  <a href="https://github.com/kiron0/quitx/actions/workflows/ci.yml"><img src="https://github.com/kiron0/quitx/actions/workflows/ci.yml/badge.svg" alt="CI Status" /></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" alt="Swift 6" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License" /></a>
</p>

<p align="center">
  <a href="https://github.com/kiron0/quitx/releases/latest">
    <img src="https://img.shields.io/badge/📥_Download_Latest_DMG-v1.0.0-FFB800?style=for-the-badge&labelColor=1a1a1a" alt="Download DMG" height="38" />
  </a>
</p>

---

## Preview

<p align="center">
  <img src="Support/Screenshots/screenshot-1.jpg" width="100%" alt="QuitX Overview - A fresh start without a restart" />
</p>

<table width="100%">
  <tr>
    <td width="50%">
      <img src="Support/Screenshots/screenshot-2.jpg" alt="Optional Force Quit" />
      <p align="center"><strong>Optional Force 💪</strong><br/><sub>Hold <kbd>⌥ Option</kbd> to transform quit into force quit.</sub></p>
    </td>
    <td width="50%">
      <img src="Support/Screenshots/screenshot-3.jpg" alt="Background Apps" />
      <p align="center"><strong>Hide and Seek 🙈</strong><br/><sub>Inspect and terminate hidden background processes.</sub></p>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <img src="Support/Screenshots/screenshot-4.jpg" alt="Customize Settings & Shortcuts" />
      <p align="center"><strong>Customize It 🤓</strong><br/><sub>Configure auto-quit timers, exclusions, shortcuts, and audio cues.</sub></p>
    </td>
  </tr>
</table>

---

## Download & Install

### Direct Download
1. Download **[QuitX-v1.0.0.dmg](https://github.com/kiron0/quitx/releases/latest/download/QuitX-v1.0.0.dmg)**.
2. Open the disk image and drag **QuitX** into your `/Applications` folder.
3. Open **QuitX** from Applications or Spotlight. It will live neatly in your menubar.

---

## Features

- ⚡ **1-Click Quit All** — Clear clutter and reclaim RAM in one click.
- ⌥ **Dynamic Force Quit** — Hold Option key to seamlessly switch any action to Force Quit.
- 🛡️ **Protected & Exclude Lists** — Safeguard music players, browsers, or critical work apps.
- ⏱️ **Auto-Quit Inactive Apps** — Automatically shuts down dormant apps after 15m, 30m, 1h, or 2h.
- 🔍 **Instant Search & Sort** — Real-time filtering with A-Z, memory, and CPU usage sorting.
- 📦 **Stash & Restore** — Snapshot open apps before rebooting and restore them anytime.
- 🎵 **Native Sound Effects** — Subtle, satisfying audio feedback on quit.
- 🪶 **Native & Lightweight** — Pure Swift & SwiftUI. Fast startup, zero battery drain.

---

## Shortcuts & Controls

| Action | Control |
|---|---|
| **Open Menu** | Click QuitX menubar icon |
| **Quit All Selected** | Click **Quit All** button |
| **Force Quit All** | Hold <kbd>⌥ Option</kbd> + click **Force Quit All** |
| **Quit Single App** | Click the circular power icon on any row |
| **Force Quit Single** | Hold <kbd>⌥ Option</kbd> + click lightning icon |
| **Select / Deselect All** | Click the gold checkbox next to Search |
| **Context Menu** | Click `•••` for Force Quit, Restart, Exclude, or Reveal |

---

## CLI Companion

QuitX also comes as a fast terminal CLI via npm:

```bash
npm install -g @coreify/quitx
quitx
```

Both app and CLI seamlessly share the same configuration at `~/.config/quitx/config.json`.

---

## License

MIT © [Toufiq Hasan Kiron](https://github.com/kiron0)
