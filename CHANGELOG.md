# Changelog

All notable changes to QuitX macOS App will be documented in this file.

## 1.1.7

### Added

- Multi-space window close observer: added `AXWindowCloseObserver` in `LastWindowQuitService` using native `AXObserver` notifications (`kAXWindowCreatedNotification` and `kAXUIElementDestroyedNotification`) to differentiate between user-initiated window closes and multi-Space/full-screen transitions.
- All-spaces window counter: added cached `allSpacesWindowCount` querying WindowServer `[.optionAll, .excludeDesktopElements]` across all virtual desktops.

### Fixed

- Multi-space false quits: switching Spaces or moving an app to full-screen mode no longer triggers premature last-window termination when windows remain open on other Spaces.

## 1.1.6

### Added

- Multi-instance application management: `AppInstanceService` detects and groups multiple running instances of the same app (`open -n`). Popover displays instance badges, collapsible instance rows with individual PID and memory stats, and individual or batch termination controls.
- Multi-instance restart: `RestartService` captures per-instance launch arguments (e.g. `--user-data-dir`) and relaunches each instance with its original arguments when restarting a multi-instance app.
- GUI integration test suite: grouped real WindowServer fixture tests and multi-instance lifecycle tests under a serialized `GUIIntegrationTests` suite (`LastWindowQuitIntegrationTests`, `MultiInstanceIntegrationTests`, `AppInstanceTests`, `RobustnessTests`).
- Space change detection: registered `NSWorkspace.activeSpaceDidChangeNotification` in `LastWindowQuitService` to track window state across Spaces and prevent false quits during Space switching.
- Quit when the last window closes: added an opt-in Automation setting ("Quit app when its last window closes") that force-quits regular apps after their last window closes via the red close button (x) or ⌘W, so they do not keep running in the background. Minimized windows, hidden apps, and windows on other Spaces are preserved. Excludes Finder, background daemons, music apps, and user exclusions.

### Changed

- Helper process management: `QuitService` discovers nested helper processes via `AppListService.runningProcessPaths()` and `ProcessTree.isDescendant`; graceful quits wait for main processes to exit before cleaning up helpers, while force quits terminate all targets concurrently.
- App-group window tracking: `LastWindowQuitService` tracks apps by bundle path groups (`appKey(for:)`) instead of single PIDs, aggregating window counts across all member processes so multi-process apps (Electron, Telegram, Discord, Docker) only quit once all windows across all helpers close.
- Performance & battery efficiency: offloaded menu bar stats sampling to background tasks to keep the main runloop responsive, and dynamically throttled `CpuUsageSampler` to 10-second idle intervals when stats popovers are closed.
- Last-window quit optimization: cached WindowServer visible window queries (`OSAllocatedUnfairLock`, 0.5s max age) and web runtime detection paths (Electron, Chromium, Slack, Discord, Telegram, Docker), eliminating duplicate window list scans.
- Quit timer precision: replaced fixed 60-second polling timer with dynamic one-shot timer targeting the earliest due deadline, eliminating execution delay drift.
- Accessibility messaging timeout: enforced a 0.5-second timeout on accessibility queries in `LastWindowQuitService` to prevent UI thread hangs on unresponsive apps.
- Settings tab views now live in purpose-named files with shared controls separated, replacing clone-style type names.
- Removed unused duplicate and legacy PNG resources from the app bundle.

### Removed

- Top processes section: removed the CPU and memory "Top Processes" list and background `TopProcessSampler` task from the stats detail popover, cutting unnecessary subprocess and kernel task walks.

### Fixed

- Quit when the last window closes: force-quits instead of sending a graceful request that background apps could ignore. It now detects AppKit-retained closed windows while preserving minimized, hidden, and off-Space windows.
- Settings: quit-on-last-window option is strictly gated behind Accessibility permissions; revoking permission automatically disables the feature and resets configuration.
- Quit timer execution: pending quit timers are retried if an existing quit operation is in-flight instead of silently dropping scheduled quits.
- Web runtime app termination: properly handles helper process and window tracking for Electron and multi-process web apps during last-window quit.
- Settings reset now asks for confirmation before restoring preferences, shortcuts, and launch-at-login defaults.
- Reopening Settings, Welcome, Help, Exclude, or Update windows from the Dock restores a minimized window instead of leaving it hidden.
- Help: Finder & Trash opens the Advanced tab, shortcut copy says "Quit all apps", menu-bar stats help includes GPU, and "Report an Issue" opens the GitHub issue tracker.
- Stats detail panel: closing clears pending toast state.
- Settings: quit-on-last-window requests Accessibility only from Automation settings, never during app launch. Granted access shows a checkmark; Remove Access disables the option and opens the native revocation pane.
- Settings: Accessibility status now refreshes live while Automation settings remain open. The last-window toggle stays clickable and opens the grant flow when access is missing.
- Build: local app bundles now use a stable designated requirement instead of a changing CDHash identity, preserving macOS privacy grants across rebuilds.
- Automation: last-window close directly force-quits eligible apps. Minimized, hidden, and off-Space windows remain open and never trigger a quit.
- Testing: added a real WindowServer integration test that opens a fixture window, performs its close-button action, and verifies automatic force termination.
- Config: debounced saves can no longer overwrite a reset or a newer immediate save, and the memory-pressure threshold shown in Settings now matches the enforced value.
- Updates: "Later" keeps the verified staged update, and failed installs no longer leak staged files.

## 1.1.5

### Added

- GPU statistics: added a GPU menu bar stat and a dedicated GPU panel reporting device, renderer and tiler utilization, GPU memory in use, allocated memory, core count and device name, sourced from IOKit `IOAccelerator` telemetry.
- Granular menu bar stats: added independent CPU, memory, GPU and battery toggles under a single master "Show stats in menu bar" switch, so any combination of stats can be shown and the master reflects whether anything is enabled.

### Changed

- Menu bar stat ordering: CPU and GPU now sit together, followed by memory and battery.
- CPU sampling: replaced the per-refresh `/bin/ps` subprocess with native `proc_taskinfo` deltas sampled once per second, cutting per-sample cost from roughly 90 ms to under 2 ms; Mach CPU counters are converted using a verified 24 ticks-per-microsecond factor with a runtime self-calibration fallback.
- Process list sampling: top CPU and memory processes now read resident size and names natively, and fall back to `ps` only for processes the kernel refuses to expose to the current user.
- App list performance: moved the window server query and PID recovery path off the main actor, and bounded the resident size cache to a fixed entry count.
- Settings window placement: the window is only repositioned when it would otherwise be off-screen, preserving the user's manual placement between openings.
- Stats panel sizing: panel height is now clamped to the display that actually hosts the menu bar item instead of the screen containing the key window.

### Fixed

- Corrupt settings recovery: an unreadable configuration is moved to a backup key instead of being left in place to fail on every launch, and malformed per-app quit rules or quit timers now drop only the offending entries instead of discarding the whole set.
- Memory pressure rescue: the apps offered for quitting are now the ones actually exceeding the memory threshold, instead of an unrelated list of windowed apps.
- Quit on sleep: terminations are dispatched synchronously before the system suspends and are verified before the machine sleeps, with a retry on wake if any app survived.
- Quit on sleep target list: the running app list is now re-scanned synchronously before the sleep quit, so apps are no longer missed when the popover was never opened and the cached snapshot was empty or stale.
- Quit on sleep and Finder: when "Include Finder Windows in list" is enabled, Finder is now part of the sleep quit targets and its windows are closed, matching the manual quit action.
- Trash on sleep: when "Include Empty Trash in list" is enabled, the Trash is now emptied as part of the sleep quit, which is the user's explicit consent for permanent deletion.
- Trash emptying: Finder's "warn before emptying" preference is restored even when the empty operation fails, and AppleScript execution is serialised so concurrent quit batches cannot race.
- Selection handling: live refresh no longer collapses the selection to the current search filter, and the "Quit All" action and its confirmation now match the full selection rather than only the visible rows.
- Icon loading: `NSWorkspace` lookups moved back onto the main actor, removing the risk of AppKit crashes and the exclude-app picker stalling on its loading placeholder.
- Rescue consent panel: the panel now dismisses when the app loses focus without being cancelled by the activation change that presented it.
- Shortcut handling: removed the duplicate local key monitor so a configured shortcut fires once instead of twice.
- Updater destination: updates replace the bundle that is actually running instead of silently installing a second copy in the user's Applications folder.
- Memory pressure threshold: the stored threshold is no longer rewritten to a fixed fraction of system memory on every launch, which previously made the feature effectively unreachable.
- Window counts and quit timers: window enumeration and per-app rule decoding no longer run on the main actor or discard unrelated configuration.

## 1.1.4

### Added

- Battery loading state: added an inline progress indicator and status message in the battery detail popover while async hardware metrics are being gathered.

### Changed

- Background battery sampling: offloaded battery detail snapshots in stats popovers to a detached utility task scoped exclusively to battery mode, with generation and cancellation tracking to prevent UI stalls.
- Popover display preparation: standardized layout flushing, display synchronization, and shadow invalidation via `prepareForDisplay()` across menu bar popovers, stats panels, rescue dialogs, and settings tooltips to eliminate visual compositing flicker.
- Menu bar stats polling lifecycle: backs off polling interval to 5 seconds and tears down the status item when menu bar stats are disabled, and removed redundant status updates from the live stats loop.

### Fixed

- Process identity verification: enforced exact bundle ID matching to prevent prefix overlap collisions with child or helper processes, falling back to sanitized name matching only when bundle ID is absent.
- Helper process containment validation: verified executable paths reside strictly within the parent app bundle's `Contents` directory using resolved, standardized file URLs.
- Auto-quit PID recovery: resolved running process IDs from executable paths when LaunchServices reports invalid or non-positive PIDs, ensuring unparented or recovered apps are tracked and idled out reliably.

## 1.1.3

### Changed

- App list service performance: indexed PID-to-path resolution to replace O(apps × processes) scans with O(1) lookups, and reused 4 KiB buffers during `proc_pidpath` queries to eliminate memory allocation churn.
- Battery sampler efficiency: added an 8-second watchdog timer to `system_profiler` child processes to prevent thread hangs, cached system health queries with background refreshes, and precompiled capacity regex matching.
- Status bar polling optimization: unified power-source sampling so battery throttle checks and menu bar status updates share a single query per tick.

## 1.1.2

### Added

- Independent menu bar stat popovers: modularized menu bar stats so clicking CPU, Memory, or Battery directly opens a dedicated popover window anchored precisely beneath that individual stat segment, removing the previous tabbed container.

### Changed

- Consistent terminology: replaced all remaining "RAM" labels and headers with "Memory" across stats views.
- Dynamic charging limit status: adjusted battery charging limit description to show "Charging to X%" while battery percentage is below limit, and "Charged to X%" once limit is reached or exceeded.
- Popover layout styling: standardized uniform 10pt content padding across stats panels to eliminate top offset and card overflow issues.

### Fixed

- Menu bar popover switching stability: resolved premature dismissal when switching between stats segments by safely tearing down observers before window reuse and avoiding focus-loss race conditions.
- General settings radio button hit testing: added full rectangular content shape to appearance option radio buttons for reliable click detection.

## 1.1.1

### Added

- Battery monitoring: optional menu bar charge status plus detailed power, capacity, health, and charging metrics.

### Changed

- Automatic update checks now run when due after launch and repeat every 24 hours while QuitX remains open, with the last attempt persisted to avoid redundant checks after relaunch.
- Smart Rescue consent now supports selecting individual targets and scrolling through long target lists.
- Refined system app protection rules: permit quitting safe, user-facing Apple utilities and document tools (Preview, System Settings, Activity Monitor, Console, Disk Utility, Archive Utility) while keeping core system UI (Dock, WindowManager, SystemUIServer, loginwindow) strictly guarded.
- Stats detail metric indicators: updated detail row status color indicators from circular dots to 10x10 rounded squares (`cornerRadius: 2.5`) to match the optical weight of process app icons.
- Centralized constants and bundle identities: consolidated primary bundle ID, supported bundle identifiers, system bundle IDs, and UserDefaults keys into `QuitXConstants`.

### Fixed

- Smart Rescue no longer refreshes its candidate list while the consent panel is visible, preserving the user's selections and keeping every target accessible.
- Stats detail actions resolve Activity Monitor by bundle identifier and open Battery Settings without force-unwrapping its URL.
- PID recovery for workspace apps: resolved process IDs via executable path matching against `proc_pidpath` when macOS LaunchServices returns an invalid PID (`-1`), ensuring apps like Preview are discovered and listed reliably.
- Termination tracking for recovered PIDs: updated `QuitService` to monitor process exit via raw PID verification when `NSRunningApplication.processIdentifier` is non-positive.
- Settings tooltip arrow and border synchronization: replaced native `NSPopover` with custom `ArrowPopoverWindow` and `arrowPopoverChrome` in `SettingsView`, unifying tooltip styling with menu bar popovers and removing the extra inner border below the arrow.

## 1.1.0

### Added

- macOS 26 Liquid Glass appearance: full native Liquid Glass UI styling and themes for macOS 26 Tahoe across the main popover, Settings window, Stats detail panel, Welcome window, and Help window, with live animated switching between Classic solid mode and Liquid Glass.
- Dedicated Automation settings tab: cleanly separated automation controls into their own dedicated tab featuring power saving, sleep and screen lock scheduling, CPU hog / memory pressure tripwires, and inactivity timeouts.
- Scheduled sleep and screen lock quit automation: restricted unattended quitting to configurable scheduled hours (default 12 AM to 6 AM) with start and end time pickers and toggle between 12-hour AM/PM and 24-hour time formats.
- Stats detail panel in menu bar: clicking the menu bar usage item opens a native-blur liquid glass panel displaying real-time CPU % and memory usage (used out of total unified memory) with custom status item arrow and auto-dismissal on click-outside, toggle, or Esc.
- Menu Bar Style & Memory format pickers: configure menu bar CPU & memory readouts with Icon (SF Symbols) vs Text (`CPU` / `MEM`) prefixes, alongside Gigabytes (GB) vs Percentage (%) memory units in Settings > General.
- Smart Rescue (USP): when a CPU or memory limit trips, QuitX safely rescues system resources by terminating inactive windowed apps only — never your frontmost app, Finder, Trash, excluded, music, or Never-ruled apps. Rescued apps land in Recently Quit for one-click reopening.
- Rescue consent panel & critical system protection: added interactive rescue consent gating and strict protections for vital macOS system processes and helper agents during resource cleanup.
- Multi-consumer CPU monitor isolation: isolated CPU tick counters in `SystemUsage.cpuPercent(consumer:)` for menu bar, popover, and detail panel to prevent sample stealing and 0% readout artifacts.
- Sticky search bar in Help: modern pinned search header in the Help sidebar with instant query matching, clear button, and empty state.
- Welcome guide appearance setup: choose between Classic and Liquid Glass appearance directly from the first-launch Welcome guide with increased, spacious layout.
- Humorous settings tooltips: comprehensive witty descriptions, tooltips, and easter eggs across all settings rows and schedule pickers.

### Changed

- Capped Recently Quit history: "Reopen Recently Quit" now tracks and presents the 5 most recently quit apps (reduced from 20) for a tighter, focused menu.
- Direct inline stepper controls: replaced static value boxes with interactive inline steppers for CPU %, memory GB thresholds, and sleep/lock time range.
- Settings sub-options visual alignment: synchronized Menu Bar style/memory formats and Sleep & Lock schedule rows into uniform, aligned sub-option layouts matching Health and Automation sections.
- Synchronized status bar refresh: menu bar stats monitoring aligned with live app timing (1s normal, 5s battery saver, 10s power saver).
- Default app selection label simplified: renamed "Deselect apps by default" to "Select apps by default" across Welcome guide and Settings > Advanced with direct positive boolean binding.
- Expanded Help documentation: updated guides for recently quit limits (up to 5), menu bar stats formatting (Icon vs Text, GB vs %), interactive detail panel, sleep & screen lock scheduling, and theme settings.

### Fixed

- Hardened process lifecycle & PID liveness: eliminated stale `NSRunningApplication` state across single-instance cleanup, auto-quit tracking, and restart verification to prevent invalid signals or false restart failures.
- Auto-quit Recently Quit tracking: routed unattended automatic quits through `QuitService` to guarantee reliable termination and populate the Recently Quit history as documented.
- Isolated update download sessions: bound async download delegates and staging tasks strictly to the active session identity, dropping stale callbacks on cancellation.
- Top process sampling concurrency throttle: enforced single in-flight `TopProcessSampler` task in Stats detail panel to prevent overlapping `ps` runs during rapid ticks.
- Installed application scan serialization: serialized cache-miss scans in `InstalledAppCatalog` so concurrent callers reuse the populated result without redundant disk sweeps.
- Relaxed VM stat memory drift tolerance: increased page cache drift allowance in stats test assertions to ensure stability on high-load CI runners.
- Removed private CPU-frequency APIs and their stats UI for future Mac App Store compatibility.
- Hardened update delivery: removed the ineffective embedded gatekeeper key and require signed update verification as the trust boundary.
- Window presentation flicker on launch: suppressed welcome window animation during automated test execution and background launch (`open -g`).
- Settings window frame positioning: stabilized window chrome updates to avoid frame shifting and layout jumps during appearance theme switches.
- Headless test execution in CI: added native build system fallback (`--build-system native`) to workflow test steps to prevent XCBuild property list initialization failures in CI runner environments.

## 1.0.9

### Added

- Per-app auto-quit rules: open the three-dot menu on any app row, choose Auto-quit, then pick 15/30 minutes, 1/2/4 hours, or Never. A per-app rule overrides the global inactivity interval; Use Default returns the app to the global setting. Works even when the global timer is off. Documented in Help > Auto Quit.
- Quit Other Apps row action: quits everything except that app, honoring the quit-all confirmation preference.
- Settings split into short General and Advanced tabs; Support tab merged into About with matching Contact button.
- Quit timers: row menu Quit In quits an app gracefully after 15, 30, or 60 minutes. Timers persist across restarts; expired ones are dropped on launch. Cancel from the same menu with remaining time shown.
- Unresponsive badge: a red triangle marks apps that ignored a previous graceful quit request, pointing at Force Quit.
- CPU hog warnings: a flame badge marks apps holding 80%+ CPU for 5+ minutes, plus one notification per offender that opens QuitX on click. Toggle in Settings > General.
- Memory pressure cleaning: optional graceful quit of regular apps over 1 GB when macOS reports memory pressure. Excluded, music, and Never-ruled apps stay safe. Toggle in Settings > General.
- Battery saver: on battery, auto-quit timeouts halve and live stats slow to every 10 seconds. Toggle in Settings > General.
- Recently quit menu: gear menu Reopen submenu relaunches recently quit apps (up to 20, deduplicated). Clearable.
- Unattended quitting on Mac sleep and screen lock: optional graceful quit of safe apps only, never forced, never confirmed. Toggles in Settings > General.
- Optional menu-bar CPU readout: total CPU percent beside the QuitX icon, refreshed every second even with the popover closed (5 seconds under battery saver). Toggle in Settings > General.

### Fixed

- Live stats no longer skip ticks when a refresh overlaps: generation counter replaces the boolean guard so the latest update always wins.
- CPU sample cache matches the 1-second menu-bar refresh, so the readout never shows stale percent; single-flight flag still prevents duplicate `ps` spawns.
- Batch quit records recently-quit apps with one `UserDefaults` write instead of one per app.
- Settings saves with `refreshAppList` debounce 0.3s, coalescing rapid toggles into one app-list refresh.
- App rows no longer observe `ConfigStore`: sort and quit mode passed as plain values, so config changes no longer re-render every row.
- Menu button image cache bounded to 64 entries via `NSCache` instead of an unbounded dictionary.
- Quit timers route through `quitSilently`: sound, recently-quit record, and resistance tracking now apply.
- Sleep, screen-lock, and memory-pressure quits reuse the app list when refreshed within 2s instead of forcing a full scan.
- Battery-saver throttle counter resets when power state changes, preventing drift in the 5-tick skip pattern.
- Update gatekeeper caches `updates.json` for 60s, removing a GitHub API fetch on every `/latest` call.
- Unresponsive badge tracks the exact process id: relaunching an app clears a stale flag instead of inheriting it, and entries for dead processes are pruned on every refresh.

### Changed

- Menu bar CPU readout interval cut from 5 seconds to 1 second; battery saver restores 5 seconds while on battery power.

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
- Real-time CPU and resident memory usage monitoring per running app.
- Protected & excluded apps list management.
- Automatic inactive app quit timer (15m, 30m, 1h, 2h).
- Instant search filter and A-Z / Memory / CPU sorting options.
- Session stash and restore for quick reboot / context switching.
- Native system sound effects and toast notifications.
- Launch at login support and automatic update checks.
