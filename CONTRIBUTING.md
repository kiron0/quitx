# Contributing to QuitX for macOS

Thank you for your interest in improving QuitX! We welcome issues, bug reports, feature requests, and pull requests.

## Development Setup

QuitX is built completely using Swift Package Manager (SPM) with no mandatory Xcode project files needed.

### Requirements
- macOS 14.0 Sonoma or later
- Swift 5.9+ / Xcode CommandLineTools or Xcode 15+

### Getting Started

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/kiron0/quitx.git
   cd quitx
   ```

2. Build debug binary:
   ```bash
   swift build
   ```

3. Run automated tests:
   ```bash
   swift test
   ```

4. Create and launch the macOS app bundle:
   ```bash
   ./Scripts/build.sh --run
   ```

## Pull Request Guidelines

- Ensure your code builds cleanly without warnings using `swift build`.
- Follow standard Swift coding style and keep the interface minimal, snappy, and native to macOS.
- Keep commits descriptive and concise.

## Testing phases

- `npm test` runs the routine regression suite. Application chooser presentation, window rendering, snapshots, and process termination integration tests are disabled. `swift test` has the same default exclusions.
- `npm test -- --filter DefaultAppsTests` runs focused regressions while editing.
- `npm run test:integration` starts local listener fixtures and verifies scanning, signals, identity checks, and port release. Run it for process, port, or termination changes. CI and release workflows run this phase separately.
- `npm run test:ui` runs window layout checks in a logged-in macOS session. It opens the application chooser. Run it for chooser, popover, or window layout changes.
- `npm run test:snapshots` renders UI assets into `.qa/snapshots`. Run it when reviewing visual changes or refreshing marketing images. The existence of `.qa/` alone never enables rendering.
- `npm run test:last-window` builds fixture apps and runs real WindowServer close-button and multi-instance checks. Run it for last-window or multi-instance behavior changes, with QuitX stopped for reliable results.

Start with focused regressions, then run `npm test` and `npm run build` before handoff. Add the relevant integration or UI phase for the changed behavior. Snapshot rendering produces review artifacts; inspect those images before claiming visual correctness. It is not a pixel comparison gate.

`npm run ship` runs routine regressions before bundling, installing, and launching. Run affected feature phases before shipping; shipping does not open test windows or regenerate screenshots. The QA bridge supports `integration`, `ui`, and `snapshots` requests alongside `test [filter]`, `check [filter]`, and `last-window`.
