<p align="center">
  <img src="Support/Icons/icon_256x256.png" width="96" height="96" alt="QuitX Icon" />
</p>

<h1 align="center">QuitX for macOS</h1>

<p align="center">
  Fast, minimal menubar companion to quit, force quit, and manage running macOS apps.
</p>

<p align="center">
  <a href="https://github.com/kiron0/quitx/actions/workflows/ci.yml"><img src="https://github.com/kiron0/quitx/actions/workflows/ci.yml/badge.svg" alt="CI Status" /></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" alt="Swift 6" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License" /></a>
</p>

<p align="center">
  <a href="https://github.com/kiron0/quitx/releases/latest">
    <img src="https://img.shields.io/github/v/release/kiron0/quitx?label=Download%20QuitX%20for%20macOS&style=for-the-badge&color=FFB800&labelColor=1a1a1a&logo=apple" alt="Download QuitX for macOS" height="38" />
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

## Install

1. Download the latest `.dmg` above.
2. Drag **QuitX** into `/Applications`.
3. Launch from Applications or Spotlight. It lives in your menu bar.

---

## CLI Companion

QuitX also includes a Node-based terminal CLI:

```bash
npm install -g @coreify/quitx
quitx
```

The macOS app stores preferences independently in standard `UserDefaults` (`com.quitx.QuitX`).

---

## License

MIT © [Toufiq Hasan Kiron](https://github.com/kiron0)
