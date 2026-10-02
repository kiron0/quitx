<p align="center">
  <img src="Support/Icons/icon_256x256.png" width="96" height="96" alt="QuitX Icon" />
</p>

<h1 align="center">QuitX for macOS</h1>

<p align="center">
  Fast, minimal menubar companion to quit, force quit, and manage running macOS apps.
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
    <img src="https://img.shields.io/badge/Download_QuitX_for_macOS-v1.0.0-FFB800?style=for-the-badge&labelColor=1a1a1a" alt="Download DMG" height="38" />
  </a>
</p>

---

## Preview

<p align="center">
  <img src="Support/Screenshots/screenshot-1.jpg" width="100%" alt="QuitX Overview" />
</p>

<table width="100%">
  <tr>
    <td width="50%">
      <img src="Support/Screenshots/screenshot-2.jpg" alt="Optional Force Quit" />
      <p align="center"><strong>Force Quit Mode</strong><br/><sub>Hold <kbd>⌥ Option</kbd> to toggle all actions to force quit.</sub></p>
    </td>
    <td width="50%">
      <img src="Support/Screenshots/screenshot-3.jpg" alt="Background Apps" />
      <p align="center"><strong>Background Processes</strong><br/><sub>Inspect and terminate hidden background processes.</sub></p>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <img src="Support/Screenshots/screenshot-4.jpg" alt="Preferences and Shortcuts" />
      <p align="center"><strong>Preferences & Shortcuts</strong><br/><sub>Configure auto-quit timers, exclusions, global shortcuts, and audio cues.</sub></p>
    </td>
  </tr>
</table>

---

## Download & Install

1. Download **[QuitX-v1.0.0.dmg](https://github.com/kiron0/quitx/releases/latest/download/QuitX-v1.0.0.dmg)**.
2. Open the disk image and drag **QuitX** into `/Applications`.
3. Open **QuitX** from Applications or Spotlight. It lives in your menu bar.

---

## Features

- **Quit All** — Close all selected applications in one click to free memory.
- **Dynamic Force Quit** — Hold Option key to transform any quit action into Force Quit.
- **Background Apps** — View and terminate dormant background processes.
- **App Exclusions** — Protect music players, browsers, or work tools from closing.
- **Auto-Quit Timer** — Automatically close inactive apps after 15m, 30m, 1h, or 2h.
- **RAM & CPU Metrics** — View resident memory usage and CPU activity per process.
- **Session Stash & Restore** — Snapshot running apps before restart and reopen them anytime.
- **Native & Lightweight** — Pure Swift & SwiftUI. Zero background drain.

---

## Controls

| Action | Shortcut / Control |
|---|---|
| Open Menu | Click QuitX menubar icon |
| Quit Selected | Click **Quit All** |
| Force Quit All | Hold <kbd>⌥ Option</kbd> + click **Force Quit All** |
| Quit Single App | Click power icon on app row |
| Force Quit Single | Hold <kbd>⌥ Option</kbd> + click power icon |
| Select / Deselect All | Click checkbox next to Search |
| App Context Menu | Click `•••` for Force Quit, Restart, Exclude, or Reveal |

---

## CLI Companion

QuitX also includes a Node-based terminal CLI:

```bash
npm install -g @coreify/quitx
quitx
```

Both app and CLI share persistent state in `UserDefaults` and configuration at `~/.config/quitx/config.json`.

---

## License

MIT © [Toufiq Hasan Kiron](https://github.com/kiron0)
