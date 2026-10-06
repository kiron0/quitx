# Changelog

All notable changes to QuitX macOS App will be documented in this file.

## 1.0.9

### Added

- Per-app auto-quit rules: open the three-dot menu on any app row, choose Auto-quit, then pick 15/30 minutes, 1/2/4 hours, or Never. A per-app rule overrides the global inactivity interval; Use Default returns the app to the global setting. Works even when the global timer is off. Documented in Help > Auto Quit.
- Quit Other Apps row action: quits everything except that app with no confirmation.
- Settings split into short General and Advanced tabs; Support tab merged into About with matching Contact button.
- Quit timers: row menu Quit In quits an app gracefully after 15, 30, or 60 minutes. Timers persist across restarts; expired ones are dropped on launch. Cancel from the same menu with remaining time shown.
- Unresponsive badge: a red triangle marks apps that ignored a previous graceful quit request, pointing at Force Quit.
- CPU hog warnings: a flame badge marks apps holding 80%+ CPU for 5+ minutes, plus one notification per offender that opens QuitX on click. Toggle in Settings > General.
- Memory pressure cleaning: optional graceful quit of regular apps over 1 GB when macOS reports memory pressure. Excluded, music, and Never-ruled apps stay safe. Toggle in Settings > General.
- Battery saver: on battery, auto-quit timeouts halve and live stats slow to every 10 seconds. Toggle in Settings > General.
- Recently quit menu: gear menu Reopen submenu relaunches recently quit apps (up to 20, deduplicated). Clearable.
- Unattended quitting on Mac sleep and screen lock: optional graceful quit of safe apps only, never forced, never confirmed. Toggles in Settings > General.
- Optional menu-bar CPU readout: total CPU percent beside the QuitX icon, refreshed every 5 seconds even with the popover closed. Toggle in Settings > General.

## 1.0.8

### Security

- Signed update pipeline with Ed25519: every release DMG is signed in CI (`Scripts/sign-update.sh`) and the app verifies the signature against a pinned public key before install. Missing or invalid signatures refuse the update.
- SHA-256 digest of the downloaded DMG is verified before mounting. Digest mismatch refuses the update.
- Extracted update bundle must pass anchored code-signature validation (`SecStaticCodeCheckValidity` with Team ID requirement), plus bundle ID and version checks.
- Update checker refuses releases with missing digest or signature metadata at check time, before any download starts.
- Rotated the gatekeeper access key. The app ships the new key; the worker accepts the old key during a grace period (`APP_SECRET_KEY_PREVIOUS`), then it can be revoked.
- Gatekeeper worker now rate-limits per IP (`/latest` 10/min, `/download` 5/min) and prefers signed `updates.json` metadata over raw GitHub digest fields.
- Tests now prove unsigned fake QuitX bundles are rejected (`.invalidSignature`); the old accept-unsigned expectation is removed.

### Fixed

- Normal Quit never escalates to `SIGKILL`. Only explicit Force Quit force-terminates after timeout.
- Cancelling a quit returns before any forced-termination logic; cancellation can no longer make quitting more destructive.
- Auto Quit only terminates gracefully and never force-kills; refused apps are rescheduled instead of killed.
- "Quit All" global shortcut quits all listed apps, not just the current selection, and honors the `confirmQuitAll` preference by opening confirmation in the popover.
- 2- and 3-app batches now honor `confirmQuitAll`; single-app quit uses `confirmIndividualAction`.
- Restart and Reveal in Finder resolve the running PID first, falling back to LaunchServices only if needed, so the correct copy of an app relaunches.
- Single-instance detection is bundle-identifier authoritative; an unrelated executable named `QuitX` can no longer be treated as another instance.
- Helper-process detection is scoped to helpers inside the selected app bundle (`Contents/`), not just bundle ID prefix matches.
- Update install is atomic: copy-first to `.QuitX.new`, swap with `.QuitX.old` backup, automatic rollback on failure. The running app is never deleted before the replacement succeeds.
- Relaunch script is static (paths passed as arguments); no Swift path interpolation, no shell-injection risk.
- Update temp directories (`QuitXUpdate-*`, `QuitXStaged-*`) and relaunch scripts are cleaned up on failure, cancellation, and window close; URLSession is invalidated when a download finishes.
- Cancel-during-verification can no longer leave orphan staged copies or flip state back to ready.
- Update verification (digest, signature, bundle validation) runs off the main thread; the UI no longer freezes while a downloaded DMG is checked.
- `NSAppleScript` (Finder/Trash actions) now runs on the main thread, where it is supported.
- User-initiated update checks open the update window even when a background check is already in flight.
- Option-key detection no longer republishes on every unrelated flags event (Caps Lock, Fn, etc.).
- Bundled app icon loading is async: cache-hit lookup only in view bodies, `LaunchServices` resolution on a background queue.
- Exclude list rows resolve app URL, name, and icon once per row instead of on every render.
- Exclude app picker reuses the cached normalized exclusion set instead of rebuilding it per body evaluation.
- `addExcludedApps` applies a whole batch in one assignment: single `@Published` fire, single set rebuild.
- Help copy no longer claims QuitX retries failed quits with force quit; it documents the real graceful behavior.
- `CONTRIBUTING.md` clone path fixed (`cd quitx`).

### Changed

- `SettingsView` (1000+ lines) split into `Settings/SettingsTabs/` per-tab views.
- Release workflow now ships both `.dmg` and `.zip` (via `ditto --sequesterRsrc`) plus signed `updates.json`; release upload fails if any asset is missing.
- Manual releases no longer pre-push a tag: the release action creates the tag from the built commit, so a failed build leaves no orphan tag.
- `Reset all` now resets everything via `SettingsResetService`: config, shortcuts, and launch-at-login.
- Version truth is `Info.plist` (`CFBundleShortVersionString`); `bump-version.sh` no longer rewrites Swift source.
- Build scripts use `set -euo pipefail` (`--build-system native` kept for this environment).
- `Package.swift` applies CLT-only test search paths conditionally by detection.
- Shortcut conflicts are rejected in Settings with an error, and failed hotkey registrations surface the real `OSStatus`.
- Installed-app picker cache uses a 60s TTL so newly installed apps appear without restarting QuitX.
- App list uses `LazyVStack`; app refreshes and the outside-click monitor only run while the popover is visible; popover resize is skipped when the frame is unchanged; CPU sampling is single-flight.
- Docs: new `worker/README.md` (routes, auth, rate limits, metadata, rotation, deploy), new "Secure Updates" section in `app/README.md`, refreshed local `.dev.vars`, audit O1 note corrected to match the rotated key design.

## 1.0.7

### Added

- Added event barrier overlay in `QuitConfirmationOverlay` to disable all underlying item clicks, hover effects, and row interactions while confirmation prompts are presented.
- Responsive popover height expansion for confirmation modals: automatically scales popover to at least 220pt when confirmation prompts are active to prevent dialog cutoff.
- Added `cardBackground` theme token to `QuitXTheme`, synchronizing light mode settings toolbar, tab headers, excluded app picker, and help navigation backgrounds with dark mode contrast standards.
- Helper and background process discovery in `QuitService`: automatically resolves all related background tasks sharing an application's bundle identifier prefix to ensure clean termination without orphaned processes.

### Changed

- Enforced fixed 220pt minimum height in `MainPopoverView` and pinned header and footer positions, allocating all intermediate vertical space to the scrollable app list without layout compression.
- Standardized confirmation prompt logic across all batch actions (`Quit All`, `Quit Selected`) to consistently adhere to the user's `confirmQuitAll` preference.
- Replaced lock contention in `AppListService` memory metric lookups with `OSAllocatedUnfairLock` and added a 1.5s per-PID cache to minimize kernel task queries.
- Throttled `/bin/ps` subprocess execution via `cpuCache` with `OSAllocatedUnfairLock` to at most once per second.
- Cached selection flags (`isAllSelected`, `isPartiallySelected`, `selectedVisibleCount`) in `AppListViewModel` `@Published` properties, removing O(n) calculations from the hot SwiftUI render path.
- Cached `appIdSet` in `AppListViewModel` to eliminate repeated `Set(apps.map(\.id))` allocations during live process stats updates.
- Maintained a normalized exclusion set in `ConfigStore` for O(1) membership validation and lookups.
- Precomputed `searchableContent` in `QuitXHelpTopic` at initialization to eliminate repetitive string joins on search keystrokes.
- Flattened help topic category sections into a unified "SEARCH RESULTS" list when an active search query is entered in `HelpView`.
- Statically cached `ByteCountFormatter` instances in `UpdateDownloadService` to eliminate high-frequency formatter allocations during downloads.
- Consolidated DMG temporary file handling in `UpdateDownloadService` into a single atomic move directly to the target staging directory.
- Cached the options `NSMenu` in `PopoverUIState` to avoid rebuilding menus on repeated gear button interactions.
- Preloaded `SoundService` audio instances (`singleSound`, `allSound`) with explicit stop/play sequencing to prevent audio cut-off on rapid actions.

### Fixed

- Fixed batch-quit failures on multi-process applications (e.g., MongoDB Compass) by terminating all related helper processes and adding automatic `forceTerminate` fallback when graceful quit exceeds the timeout deadline.
- Added a 1.5-second watchdog termination timer to `/bin/ps` executions in `AppListService` to prevent indefinite thread blockage.
- Fixed potential data loss in `ConfigStore.save()` during rapid application exit by capturing configuration snapshots by value and flushing work items in `deinit`.
- Fixed cancellation handling in `QuitService.quitOne` wait loop to immediately abort when parent task is cancelled.
- Fixed `NSWorkspace` observer memory leak in `AutoQuitService` by deregistering the observer inside `deinit`.
- Hardened `SingleInstanceService` lifecycle with `@MainActor` isolation and explicit `stopMonitoring()`, eliminating off-main deallocation issues.
- Optimized `AppInfo.id` generation for grouped background apps from O(n log n) sorting down to O(1).
- Debounced Carbon hotkey re-registration in `ShortcutManager` by 50ms to prevent registration thrashing during rapid settings toggles.
- Fixed hardcoded vertical `+4` pixel offset in `StatusItemController` context menu positioning.
- Fixed temporary directory and mount point leaks during failed DMG extractions in `UpdateDownloadService` by reordering `defer` cleanup.
- Fixed `VersionComparator` prefix and suffix handling to accurately parse version strings during version preference checks.
- Fixed race condition in `RestartService.restart` by polling process termination state with a 2-second deadline instead of a static 500ms sleep.
- Removed embedded API secret key from source code; moved key to `Support/Info.plist` with environment variable fallback support.

## 1.0.6

### Added

- In-popover `QuitConfirmationOverlay` modal replacing macOS native `NSAlert` dialogs, fixing unresponsive sheets on borderless menu bar panels.
- User configuration setting "Confirm single app quit & restart" in Settings > General, allowing toggleable confirmation prompts for individual app actions.
- Permanent static "Force Quit" action in each app row's three-dot options menu alongside standard "Quit", regardless of Option modifier key state.

### Changed

- Replaced global `NSEvent` key monitoring with Carbon `RegisterEventHotKey` APIs for background shortcuts, enabling reliable global shortcut activation without requiring Accessibility permissions.
- Improved hotkey event decoder to correctly handle ASCII control character offsets and prevent modifier-key dropping during shortcut recording.
- Replaced legacy `Makefile` with unified native shell scripts (`Scripts/build.sh`, `Scripts/ship.sh`) and direct Swift Package Manager commands in `package.json` and CI workflows.
- Optimized app row layout spacing in main popover: widened visible application title container to 108pt within the fixed 270pt popover window, preventing truncation of common application names like "Google Chrome" and "Activity Monitor".
- Adjusted resource usage display frame width to 46pt to prevent high memory readings (e.g. `15.4 GB`) from clipping.
- Synchronized `Force Quit Selected` button text color with `Quit All Selected` and wired it to the confirmation modal dialog.
- Unified dual 50-case keycode translation maps in `ShortcutManager` into a single bidirectional dictionary.
- Moved AppleScript execution in `QuitService` to a detached background task to prevent blocking the main thread during Finder or Trash operations.
- Debounced `ConfigStore.save()` disk writes by 150ms using `DispatchWorkItem` to prevent write bursts during rapid settings toggles.
- Decoupled `AppListViewModel.updateLiveStats` into lightweight `fetchLiveStats`, refreshing CPU and memory metrics in-place every 2 seconds without full process re-enumeration or window list queries.
- Bounded `AppIconCache` image memory with `countLimit = 150`.
- Added TTL-based caching for per-PID memory and CPU metrics in `AppListService` to avoid redundant system calls and subprocess executions.
- Cached rendered menu bar status item icons in `StatusItemController` to eliminate repeated filesystem reads.
- Hoisted popover styling constants and reused `PopoverContainerShape` instances in `MainPopoverView` to minimize per-render overhead.
- Cached excluded application set against modification in `AutoQuitService`.
- Hardened update API key handling in `QuitXConstants` to support dynamic bundle and environment injection with obfuscated fallback components.

### Fixed

- Fixed unclickable confirmation alerts when quitting 4 or more applications from the popover.
- Fixed keyboard navigation shortcuts (`Esc` to dismiss confirmation, `Return` to confirm action) inside the popover window.
- Fixed `SettingsTab.general.contentHeight` unit test expectation mismatch following the addition of the individual confirmation toggle.
- Fixed potential pipe read deadlock in `AppListService.fetchCpuUsages()` by waiting for process exit before reading stdout.
- Fixed unhandled regex crash risk in `SystemAppProtection` by using graceful optional regex compilation.
- Enforced `@MainActor` thread-safety on `AppIconCache` AppKit operations.
- Fixed timer lifecycle leak in `AutoQuitService` by adding explicit `stopTracking()` and deinit invalidation.
- Fixed `QuitXConfig.SortBy` decoder fallback to align with default `.name` alphabetical sort instead of resetting to CPU sort.
- Fixed unreleased `DistributedNotificationCenter` observer tokens on application termination in `AppDelegate`.
- Fixed SwiftUI list identity collision risk for grouped background apps and apps without bundle IDs in `AppInfo`.
- Clarified `restartApp` failure toast messaging with actionable force-quit guidance.
- Fixed CoreGraphics off-main-thread warnings on macOS 14+ by capturing window list snapshots on `@MainActor`.

## 1.0.5

### Added

- Reusable `SystemAppProtection` architecture utility consolidating system daemon protection rules, invisible Unicode scalar cleaning, and parenthetical helper grouping logic across all core services and settings views.
- Dedicated update check window (`AppUpdateWindowController`) with an immediate indeterminate loading indicator and real-time status presentation for update discovery.
- Added "Check for Updates..." to both the popover options menu and status bar right-click context menu.
- Support for detecting APFS Cryptex applications (`/System/Cryptexes/App/System/Applications`) and translocated applications (e.g., Maccy running from `/private/var/folders/...`) in the exclude app picker.

### Changed

- Replaced fragile hardcoded protected bundle identifier arrays with architecture-driven system protection (protects `/System/Library/CoreServices/`, `/System/Library/PrivateFrameworks/`, `/usr/`, `/Library/Apple/`, and system accessory agents while leaving user-facing Apple apps like Safari, Music, Notes, and Pages selectable and quit-able).
- "Deselect apps by default" configuration setting now defaults to `false` (`defaultSelectAll = true`).
- Optimized `ExcludeAppPickerView` scanning and selection state computation (`selectionState(for:)`) to O(N) single-pass without redundant intermediate array allocations.
- Optimized `AppListService.fetchCpuUsages()` to use direct string slice scanning, eliminating per-process substring array allocations.
- Replaced regex compilation in `cleanAppName` with allocation-free Unicode scalar filtering for invisible bidi and zero-width formatting characters (`\u{200B}-\u{200D}`, `\u{200E}`, `\u{200F}`, `\u{FEFF}`).
- Replaced multi-pass directory walking in `InstalledApplicationScanner` with deduplicated root scanning and unified `processAppBundle` + `insertOrUpdate` pipeline, cutting ~75 lines of duplicated logic.
- Exclude app picker search query now strictly respects the `showBackgroundApps` toggle.
- Unified `AppIconCache` key resolution between synchronous and asynchronous loading paths with Sendable `String` keys to prevent cache misses and eliminate concurrency warnings.
- Pre-resolved application bundle URLs before termination in `RestartService` for reliable relaunching of background and helper applications.
- "Reveal in Finder" in popover app rows now falls back to PID-based bundle URLs when LaunchServices URLs are unavailable.

### Fixed

- Fixed critical bug where Safari was missing from the Exclude App Picker when not running, caused by the `UF_HIDDEN` flag on the `/Applications/Safari.app` APFS Cryptex firmlink interacting with `.skipsHiddenFiles` in `DirectoryEnumerator`.
- Fixed window centering across all auxiliary windows (`HelpWindowController`, `SettingsWindowController`, `AppUpdateWindowController`, `ExcludeAppPickerWindowController`) to ensure consistent horizontal centering and top-biased vertical positioning.
- Fixed non-Sendable `NSString` capture warnings across AppKit icon loaders.
- Removed outdated "View/Hide background apps" option from the status bar menu.

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
