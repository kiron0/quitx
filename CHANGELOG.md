# Changelog

All notable changes to QuitX macOS App will be documented in this file.

## 1.0.4


### Fixed

- `WelcomeWindowController.close()` and `HelpWindowController.close()` did not call `WindowActivationCoordinator.update()`, leaving the app stuck in `.regular` activation policy after programmatic window dismissal.
- `AppListViewModel.updateLiveStats()` incremented `scanGeneration`, silently discarding results from any concurrent `refresh()` call due to a false-positive generation mismatch.
- `SoundService` created `NSSound` instances with no strong reference, allowing ARC to deallocate them before playback completed, causing intermittent silent audio.
- `AppUpdateWindowController` had a dead `closeWindow()` method that was an unreachable duplicate of `close()`.

### Changed

- `ShortcutManager.restartMonitoring()` now skips installing global and local key-event monitors when all three shortcuts are disabled, avoiding unnecessary system-wide keystroke interception.
- `AppDelegate.showSettingsWindow(_:)` and `showPreferencesWindow(_:)` no longer wrap synchronous `@MainActor` calls in redundant `Task { @MainActor in }` closures.


## 1.0.3

### Added

- Native in-app update downloader and installer pipeline (`UpdateDownloadService`) supporting direct background downloading, DMG mounting, bundle verification, and atomic swap.
- Dedicated update window (`AppUpdateWindowController` and `AppUpdateView`) displaying download progress, transfer speed, staged verification, and one-click restart.
- Reusable `QuitXMenuButton` supporting unified accent glow on hover and click matching the quit action style.
- Version bump automation script (`Scripts/bump-version.sh`) and `make bump` / `npm run bump` commands for interactive semver and build updates across all project manifests.
- Comprehensive test suite for update download flows, checksum checks, DMG verification, and selection state retention (`AppUpdateTests`, `ViewModelTests`).

### Changed

- App row context menu trigger (3-dot icon) and popover footer menu trigger now share unified hover and active accent highlight effects.
- General tab help icon (`?`) updated with hover active state and native system blur background for its tooltip toast.
- Update checker now references `QuitXConstants.appVersion` as the central source of truth for current client version.
- Replaced custom DMG extraction script paths with atomic relaunch script handling process exit polling, bundle replacement, quarantine removal, and application relaunch.

### Fixed

- Preserved user manual checkbox selections across popover dismiss and reopen events, resolving unexpected deselection behavior.
- Resolved conflict between the "Deselect apps after quit" setting and active UI selection lock states during background application scans.
- Prevented keyboard focus trapping when cycling popover window visibility.

## 1.0.2

### Added

- Single-instance enforcement (`SingleInstanceService`) via local IPC socket to prevent duplicate QuitX processes.
- Custom anchored popover window (`MenuPopupWindow`) featuring a native macOS replica 32×12pt arrow with cubic Bézier shoulder curves.
- Native `VisualEffectBlur` material styling for system menus and popover views.

### Changed

- Prevented default autofocus on popover search bar on open to avoid trapping keystrokes.
- Restored "Quit All" button 6pt corner radius and border overlay design matching v1.0.1 aesthetic.
- Menubar right-click "About" action now directs straight to the About tab in Settings.
- Repositioned General Settings help tooltip below button with native system blur styling.

### Removed

- Stash and Restore session feature end-to-end to keep application lean and focused solely on process termination.

## 1.0.1

### Added

- In-progress loading spinner for individual app quit and restart actions.
- Batch quitting progress indicator on "Quit All" / "Quit Selected" button.
- Dynamic status toasts with status icons for successful quits, failed terminations, and restart errors.
- Legacy configuration migration with automatic fallback defaults for new settings.

### Changed

- Selection counter now accurately reflects visible items when background apps are hidden.
- Search queries now trim leading and trailing whitespace automatically.
- Stash service only purges saved session when all restorable applications launch successfully.
- Process termination verifies application identity matches target before signaling.
- Minimum supported macOS version updated to 14.0+.

### Fixed

- Prevented concurrent quit and restart requests while an operation is already pending.
- Excluded music applications properly from background auto-quit routines.

## 1.0.0

### Added

- Initial release of QuitX for macOS (native Swift, AppKit & SwiftUI).
- Menubar status item with fast popover UI.
- 1-Click Quit All and Option-key dynamic Force Quit All.
- Real-time CPU and resident memory (RAM) usage monitoring per running app.
- Protected & excluded apps list management.
- Automatic inactive app quit timer (15m, 30m, 1h, 2h).
- Instant search filter and A-Z / RAM / CPU sorting options.
- Session stash and restore for quick reboot / context switching.
- Native system sound effects and toast notifications.
- Launch at login support and automatic update checks.
