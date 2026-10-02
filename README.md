# QuitX for macOS

<p align="center">
  <img src="Support/Icons/icon_256x256.png" width="128" height="128" alt="QuitX Icon" />
</p>

<p align="center">
  <strong>Fast, minimal menubar companion to quit, force quit, and manage running macOS apps.</strong>
</p>

<p align="center">
  <a href="https://github.com/kiron0/quitx/actions/workflows/ci.yml"><img src="https://github.com/kiron0/quitx/actions/workflows/ci.yml/badge.svg" alt="CI Status" /></a>
  <a href="https://github.com/kiron0/quitx/releases"><img src="https://img.shields.io/github/v/release/kiron0/quitx?color=FFB800" alt="Latest Release" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License" /></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift" alt="Swift 5.9+" />
</p>

---

QuitX lives silently in your macOS menu bar. Open it with a click to see all running applications with real-time memory usage, instantly quit unwanted apps, or hold <kbd>⌥ Option</kbd> to force-quit stuck processes.

## ✨ Features

- ⚡ **1-Click Quit All** — Clean up your workspace and reclaim system RAM instantly.
- ⚡ **Dynamic Force Quit** — Hold <kbd>⌥ Option</kbd> to seamlessly transform all actions into Force Quit mode.
- 🛡️ **Protected & Exclude Lists** — Safely protect apps (e.g. music players, browsers, background agents) from accidental termination.
- ⏰ **Auto-Quit Inactive Apps** — Automatically shut down unused apps after 15m, 30m, 1h, or 2h of inactivity.
- 🔍 **Instant Search** — Filter running apps on the fly.
- 📊 **RAM & Resource Monitoring** — Live resident memory statistics per running application.
- 📦 **Stash & Restore Sessions** — Stash your current running apps before a reboot or context switch, and restore them anytime.
- 🎧 **Native Sound Effects** — Satisfying audio feedback on quits.
- ⚙️ **Full CLI Interop** — Syncs automatically with the `@coreify/quitx` CLI configuration at `~/.config/quitx/config.json`.
- 🪶 **Ultra Lightweight** — Native Swift, AppKit & SwiftUI with zero external dependencies.

---

## ⌨️ Shortcuts & Controls

| Action | Control |
|---|---|
| **Open Menu** | Click QuitX menubar icon |
| **Quit All Selected** | Click **Quit All** button |
| **Force Quit All** | Hold <kbd>⌥ Option</kbd> + click **Force Quit All** |
| **Toggle Single App** | Click the circular power icon on any row |
| **Force Quit Single** | Hold <kbd>⌥ Option</kbd> + click lightning icon |
| **Select / Deselect All** | Click the gold checkbox next to Search |
| **App Context Menu** | Click `•••` (Force quit, restart, reveal in Finder, exclude) |

---

## 🚀 Installation

### Option 1: Download Pre-built Release
Download `QuitX-v*.dmg` from [Releases](https://github.com/kiron0/quitx/releases), open the disk image, and drag `QuitX.app` into `/Applications`.

### Option 2: Build From Source

```bash
# Clone the repository
git clone https://github.com/kiron0/quitx.git
cd quitx/app

# Build and package the application bundle
make bundle

# Launch QuitX
make run
```

---

## 🛠️ Architecture

- **Language:** Swift 5.9+ / macOS 14.0+
- **UI:** SwiftUI + AppKit (`NSStatusItem`, `NSPopover`, `NSWindowController`)
- **Build System:** Swift Package Manager (`--build-system native`)
- **Dependencies:** 0 third-party packages (100% native Apple SDKs)
- **Config Path:** `~/.config/quitx/config.json`

```
QuitX/
├── Sources/QuitX/
│   ├── App/             # App lifecycle, AppDelegate, StatusItemController
│   ├── Core/
│   │   ├── Models/      # AppInfo, QuitXConfig
│   │   ├── Services/    # AppListService, QuitService, AutoQuitService, SoundService
│   │   └── Config/      # ConfigStore (JSON sync)
│   └── UI/
│       ├── Popover/     # Main popover, AppList, AppRowView, Search
│       └── Settings/    # Preferences window & controller
├── Support/
│   ├── Icons/           # AppIcon.icns, menubar templates, vector assets
│   ├── Sounds/          # Authentic sound effects (.aiff)
│   └── Info.plist       # Agent / LSUIElement bundle metadata
└── Tests/               # Automated unit tests
```

---

## 🤝 Contributing

Contributions are welcome! Please check out [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

## 📄 License

QuitX is open-source software licensed under the [MIT License](LICENSE).
