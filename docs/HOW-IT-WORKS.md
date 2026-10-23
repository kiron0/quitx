# How QuitX works

QuitX is a menu bar app that quits, force quits and manages running macOS apps. Everything it does uses public macOS APIs. It never reads other apps' files and never sends your data anywhere. The only network request it makes is the update check to GitHub.

## Quitting apps

| Feature | API | QuitX |
|---|---|---|
| List running apps | `NSWorkspace.runningApplications`, filtered by activation policy | `Core/Services/AppListService.swift` |
| One row per app | Instances are grouped by bundle identifier and bundle location; helpers are matched by bundle path and process ancestry | `Core/Services/AppInstanceService.swift` |
| Quit | `NSRunningApplication.terminate()` for every instance of the app. A normal quit never escalates to a force quit. | `Core/Services/QuitService.swift` |
| Apps that stay in the background | If the app is still running after the quit request, QuitX sends the quit again (attempts 15 and 30) instead of asking you to do it twice | `QuitService` |
| Force quit | `NSRunningApplication.forceTerminate()`, only when you choose it (or hold ⌥) | `QuitService` |
| Windows menu | Accessibility `AXWindows`, shown only when an app has more than one window | `UI/Popover/AppRowView.swift` |
| Protected apps | Finder, Trash and system processes are never offered for quitting | `Core/Helpers/SystemAppProtection.swift` |

## Automation

| Feature | API | QuitX |
|---|---|---|
| Quit when the last window closes | Accessibility `AXObserver` (`kAXWindowCreatedNotification`, `kAXUIElementDestroyedNotification`) plus a WindowServer count across all Spaces. A click on a window's close button or ⌘W marks close intent, so apps that only hide their window (Discord, Slack) still quit. Space switches, full screen, minimize and hide never count as a close. | `Core/Services/LastWindowQuitService.swift` |
| Apps with no windows | An app with no windows at all (Docker style) quits completely, with all its helpers | `LastWindowQuitService` |
| Quit inactive apps | Last-activation timestamps from `NSWorkspace.didActivateApplicationNotification` | `Core/Services/AutoQuitService.swift` |
| Quit timers and per-app rules | One-shot timers per app | `Core/Services/QuitTimerService.swift`, `PerAppQuitRule.swift` |
| Quit on sleep | `NSWorkspace.willSleepNotification` and `didWakeNotification`, limited to the time range you set | `Core/Services/SleepService.swift` |
| Memory pressure and battery saver | `DispatchSource.makeMemoryPressureSource`, IOKit power sources | `MemoryPressureService.swift`, `BatterySaver.swift` |
| CPU hog alerts | `proc_listallpids` and `proc_taskinfo` sampled with an adaptive interval | `CpuUsageSampler.swift`, `HogMonitor.swift` |
| Global shortcuts | Carbon `RegisterEventHotKey` | `Core/Services/ShortcutManager.swift` |

## Accessibility permission

QuitX only needs Accessibility for window-based features. `Core/Services/AccessibilityPermission.swift` owns that state: it never prompts on its own, listens for the system `com.apple.accessibility.api` change notification, and offers Repair (`tccutil reset`) when a grant was lost. Builds use a stable designated requirement, so macOS keeps the grant across updates. See [SIGNING.md](SIGNING.md).

## In-app updates

QuitX updates itself straight from this repository's GitHub Releases. There is no update server, no API key and no third-party URL.

| Step | API | QuitX |
|---|---|---|
| Find the latest version | GitHub REST API `GET /repos/kiron0/quitx/releases/latest`, with the `ETag` sent back as `If-None-Match` so unchanged answers (304) don't count against the rate limit | `Core/Services/UpdateChecker.swift` |
| When it checks | 20 seconds after launch, then every 6 hours and after the Mac wakes, if **Check for updates automatically** is on. A failed check retries after 30 minutes. | `UpdateChecker.startAutomaticChecks` |
| Compare versions | Numeric comparison of `CFBundleShortVersionString` with the release tag; drafts and pre-releases are ignored | `Core/Helpers/VersionComparator.swift` |
| Tell you | A red dot on the menu bar icon, an **Update to vX…** item at the top of both menus, and one notification per version | `UI/MenuBar/StatusItemController.swift`, `UpdateNotifier.swift` |
| Download | `URLSession` download of the release's `QuitX-vX.dmg` asset, with progress. With **Download and prepare updates automatically** on, this happens in the background. | `Core/Services/UpdateDownloadService.swift` |
| Verify | SHA-256 against the asset `digest` GitHub publishes; mount the DMG read-only; bundle identifier and version must match the release; `SecStaticCodeCheckValidity` with strict, nested-code checks, plus the running app's designated requirement when it isn't ad-hoc signed | `UpdateDownloadService` |
| Install | A small shell helper waits for QuitX to quit, copies the new app next to the old one, swaps them (restoring the old one if the move fails), removes quarantine and reopens QuitX. If the app folder needs an administrator, macOS asks for a password. A copy running from the disk image or a translocated folder is installed to `/Applications`. | `UpdateDownloadService.installAndRelaunch` |

Settings and excluded apps live in `UserDefaults` (`io.coreify.quitx`), so they carry over unchanged.

### Older versions

QuitX 1.1.8 and earlier asked a Cloudflare Worker for updates and required an Ed25519-signed `updates.json`. The release workflow still publishes that file when the `UPDATE_ED25519_PRIVATE_KEY` secret exists, so those versions can update once to a GitHub-based build. After most people have moved over, delete the secret and the Worker; older copies can then update from the website or the Releases page.

## Terminal installer

`curl -fsSL https://quitx.kiron.dev/install | bash` runs `site/install`, which GitHub Pages serves from the website. It finds the latest release through the GitHub API, downloads the DMG, checks the SHA-256 digest GitHub publishes, the bundle identifier, the version and the code signature, then swaps the app into `/Applications` (restoring the old copy if that fails) and opens it. It never runs as root and uses `sudo` only when `/Applications` isn't writable.

## Releasing

See the Releasing section of [SIGNING.md](SIGNING.md) and `.github/workflows/release.yml`. The workflow tests, builds and signs the app, packages the DMG and zip, copies this version's `CHANGELOG.md` section into the release notes (which the update window shows), and publishes the GitHub Release. The website in `site/` (including the `install` script) deploys to GitHub Pages at quitx.kiron.dev through `.github/workflows/pages.yml`.
