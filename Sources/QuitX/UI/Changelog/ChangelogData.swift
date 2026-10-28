import Foundation

extension ChangelogProvider {
    static let appReleases: [ReleaseChangelog] = [
        ReleaseChangelog("1.2.3", "Applications & cleanup in Settings, reorderable stats", [
            ("New Features", [
                "**Applications in Settings**: Uninstall Apps now lives in the Settings sidebar instead of a separate window, with a Leftovers scanner for files left behind by apps that are no longer installed.",
                "**Cleanup Scanners**: Review-first pages for System Junk, User Cache, Mail Files, Trash Bins, Large & Old Files, AI Apps, Xcode Junk, Homebrew, Node, and Docker caches.",
                "**Reorder Menu Bar Stats**: Drag CPU, GPU, Memory, Battery, and Ports into any order in Settings ▸ General. Clicking a stat still opens its own window. The port count switch now lives there too, instead of in Settings ▸ Ports.",
                "**Quick Clean**: Turn on the Cleanup stat to see reclaimable cache space in the menu bar. Click it to tick User Caches, User Logs, Developer Caches, or Trash and clean them after a confirmation. Choose how often it rescans when you open the window and in the background.",
                "**Friendlier Installer**: The download now opens to a styled window with QuitX, an arrow, and your Applications folder, so installing is one drag.",
                "**Support Link**: Buy Me a Coffee on the About page."
            ]),
            ("Improvements", [
                "**Battery Temperature**: The Battery window shows temperature again on Macs where macOS stopped reporting it, read straight from the battery sensors.",
                "**Permanent Removal**: Confirmed uninstall, leftover, and cleanup selections are deleted permanently instead of being moved to Trash.",
                "**Safer Leftovers**: Containers, launch items, Application Support folders, and files from vendors you still have apps from now need your review before removal.",
                "**Lighter in the Background**: Quit When Last Window Closes does far less work each second, and cleanup scans stop as soon as you leave them and use less memory.",
                "**Faster Lists**: The app list, cleanup pages, and leftovers filter and sort only when something changes, and app sizes arrive in batches."
            ])
        ]),

        ReleaseChangelog("1.2.2", "Settings redesign, Marquee integration & optimizations", [
            ("New Features", [
                "**Settings Redesign**: Settings now features a spacious window with an organized sidebar, instant search, and an Overview dashboard showing each feature's status.",
                "**More Apps ▸ Marquee**: Explore Marquee, a menu bar companion app for screenshots and clipboard history, right from Settings.",
                "**Marquee Window Protection**: Marquee is now protected from accidental quitting, keeping it active in your menu bar when its window is closed."
            ]),
            ("Improvements", [
                "**Settings Polish**: Redesigned About tab resource cards with quick links to Help, Updates, and GitHub issues, and added custom outline icons.",
                "**Live Port Count**: Menu bar listening port count now updates along with your Ports refresh rate and reuses recent scan data to save battery and CPU.",
                "**Performance Optimizations**: Optimized background refresh loops for menu bar stats and port scanners to minimize CPU wakeups.",
                "**Refined Confirmations**: Consistent dark surface styling for quit and kill action confirmation overlays."
            ])
        ]),

        ReleaseChangelog("1.2.1", "Ports tab, faster updates & clearer labels", [
            ("New Features", [
                "**Ports Tab**: Turn on port killing in Settings ▸ Ports and switch between Apps and Ports above the main button. See every listening port with its app, folder and Docker container, and free it in one click.",
                "**Always Up to Date**: The Ports list refreshes on its own while it's open, every 1 to 10 seconds, with live CPU and memory.",
                "**Smart Kill**: Safely stops stubborn listeners, dev servers with child processes, background Homebrew services, and Docker containers. Hold ⌥ to force kill.",
                "**Row Tools**: View port details, trace process trees, interrupt, exclude, copy details, or jump straight to Terminal or the browser.",
                "**Exclude Ports**: Settings ▸ Exclude gets an Apps / Ports switch. Pick ports from the ones listening now or type them, with ranges like 8000-8010.",
                "**Light on Your Mac**: Ports are detected directly from the system in milliseconds without heavy background commands, using almost no CPU.",
                "**Quieter in the Background**: Quit When Last Window Closes and Auto Quit no longer ask macOS about every running app every second, so QuitX stays near 0% CPU when idle.",
                "**Listening Port Count**: Optionally show how many ports are listening in the menu bar stats, next to CPU and memory."
            ]),
            ("Improvements", [
                "**Remembers Your Tab**: The menu opens on the tab you used last.",
                "**Menu Bar Refresh**: Choose how often menu bar stats update, from every second to every 10 seconds. QuitX also slows down by itself in Low Power Mode, so Save power on battery is gone.",
                "**Matching Stats**: The stats window you open from the menu bar now updates at the same pace as the menu bar and shows the exact same CPU and memory numbers.",
                "**Wider Menu and Settings**: More room for app and port names.",
                "**Faster Update Install**: Preparing a downloaded update no longer re-verifies the whole disk image, and new releases use a faster disk image format.",
                "**Clear Menu Item Labels**: About and Quit menu items in the menu bar right-click menu, popover gear menu, and Help view are now explicitly labeled **About QuitX** and **Quit QuitX**."
            ])
        ]),

        ReleaseChangelog("1.2.0", "App uninstaller & hardware-aware settings", [
            ("New Features", [
                "**Uninstall Apps**: Choose Uninstall in an app's ••• menu. QuitX finds the app and its leftover support files, caches, preferences, containers, saved state, logs, and launch items, with sizes. Everything starts selected; confirm and they go to the Trash.",
                "**Uninstall Several at Once**: Uninstall Apps in the menu lists your installed apps. Pick as many as you like and review all their files together.",
                "**Clean Exit**: The app is force quit before removal. Hover any file to show it in Finder or remove just that one.",
                "**Safe by Design**: Apple apps, parts of macOS, helpers inside other apps, and QuitX itself can't be uninstalled, and your Documents and Desktop are never searched."
            ]),
            ("Improvements", [
                "**Uninstaller Visuals**: Radar pulse scan animation with live item counter; leftover rows display file paths.",
                "**Settings Match Your Mac**: Battery stats only appear on Macs with a battery, and the GPU stat only when macOS reports GPU usage. A Mac mini no longer shows options it can't use.",
                "**Login Item Approval**: Settings ▸ General shows an inline Allow button if macOS requires permission for Open at login."
            ]),
            ("Fixes", [
                "**Battery Stats Panel Stability**: The battery stats panel no longer resizes while loading, reserving full layout height with placeholder rows and an animated icon.",
                "**Empty Menu Bar Stats**: A battery-only stats setting carried over to a Mac without a battery no longer leaves an empty menu bar item."
            ])
        ]),

        ReleaseChangelog("1.1.9", "In-app updates, What's New redesign & settings polish", [
            ("New Features", [
                "**Updates Straight From GitHub**: QuitX now checks this project's GitHub Releases directly. No update server, no keys, nothing else in between.",
                "**Update in the Menu**: When a new version ships, the menu bar icon gets a red dot and both menus offer Update or Restart to Update at the top.",
                "**Automatic Update Settings**: Settings ▸ General lets you turn automatic checks on or off and have new versions download and verify in the background."
            ]),
            ("Improvements", [
                "**Refined What's New Experience**: Compact welcome-style view focusing on the latest release, with quick sidebar access to browse previous version notes.",
                "**Playful Settings Tooltips**: Added humorous tooltips and icons across Shortcuts, Exclusions, General, and About tabs.",
                "**One-Line Terminal Installer**: Quick, verified setup directly from the terminal with automatic integrity checks."
            ]),
            ("Fixes", [
                "**Changelog Navigation**: Resolved version selection desync when switching between compact and detailed release views.",
                "**Window Layout**: Fixed bottom spacing gap in What's New window on compact and expanded modes."
            ])
        ]),

        ReleaseChangelog("1.1.8", "Accessibility permission persistence & data access fixes", [
            ("Fixes", [
                "**Accessibility Survives Updates**: QuitX keeps its Accessibility permission across updates. If macOS dropped it after updating from an older version, Settings ▸ Automation offers a one-click Repair.",
                "**Discord & Electron Apps**: Apps that only hide their window when you click the red close button now quit as expected when that was their last window.",
                "**No More Data Access Warnings**: QuitX no longer looks inside other apps' private data or your personal folders while detecting browser profiles."
            ])
        ]),

        ReleaseChangelog("1.1.7", "What's New window & multi-space window improvements", [
            ("New Features", [
                "**What's New Window**: A dedicated version history window to explore highlights, improvements, and fixes whenever QuitX updates. Open it anytime from About, Settings, or the menu bar.",
                "**Multi-Space Smart Detection**: Switching between macOS Spaces or working in full-screen mode no longer triggers accidental app quits when windows remain open on other virtual desktops.",
                "**Window Controls**: Apps with more than one window get a Windows menu in their row to show or close a single window, or close one Chrome profile's windows."
            ]),
            ("Fixes", [
                "**One Click Quits Background Apps**: Apps that stay in the background after the first quit request are now asked again automatically, so a single Quit is enough.",
                "**Docker-Style Apps**: Apps that hide their Dock icon after closing their window now quit when their last window closes, together with their background services.",
                "**Closing One of Several Windows**: Quit When Last Window Closes waits until every window of the app, across all of its instances, is closed."
            ]),
            ("Improvements", [
                "**Accurate Multi-Window Tracking**: Accurately tracks open windows across all virtual desktops and displays so multi-window apps stay open until their final window is closed.",
                "**Automatic Update Highlights**: What's New automatically appears once right after updating and restarting QuitX, staying neatly tucked away until your next update.",
                "**Native Window Chrome**: Clean transparent title bar and sidebar layout perfectly aligned with macOS traffic lights and standard keyboard shortcuts.",
                "**Polished Settings Tooltips**: Added helpful descriptions and playful icons across Settings tabs."
            ])
        ]),

        ReleaseChangelog("1.1.6", "Multi-instance app support & smart helper cleanup", [
            ("New Features", [
                "**Multi-Instance Support**: Apps running more than once (such as separate **Google Chrome**, **Brave**, or **VS Code** instances) appear as one row; Quit and Restart act on every instance.",
                "**Smart Multi-Instance Restart**: When restarting an app running with multiple profiles, QuitX captures each profile's original command-line arguments and relaunches them accurately.",
                "**Quit on Last Window Close**: Opt-in automation setting that gracefully terminates apps when you close their last window via the red close button or `⌘W`, keeping your system clean and uncluttered."
            ]),
            ("Improvements", [
                "**Deep Helper Process Termination**: Quitting complex apps like **Discord**, **Docker**, **Telegram**, or **Slack** cleanly shuts down all background helpers and leftover services in one go.",
                "**Zero-Lag Background Stats**: Smoothly gathers menu bar metrics in the background, eliminating any interface stutter or delays.",
                "**On-Time Quit Timers**: Replaced periodic polling with one-shot timers so scheduled app quits run on time instead of up to a minute late.",
                "**Streamlined Settings Design**: Reorganized settings into clean, dedicated tab layouts with instant live permission toggles."
            ])
        ]),

        ReleaseChangelog("1.1.5", "Real-time GPU statistics & instant CPU sampling", [
            ("New Features", [
                "**Live Menu Bar GPU Statistics**: Monitor graphics processor utilization, GPU memory allocation, renderer load, and device core counts straight from your menu bar.",
                "**Granular Menu Bar Toggles**: Independently toggle CPU, Memory, GPU, and Battery metrics under a master switch so your menu bar shows only what you care about."
            ]),
            ("Improvements", [
                "**Instant CPU Sampling**: Greatly reduced CPU measurement overhead, delivering instant updates with virtually zero battery impact.",
                "**Rock-Solid Sleep Quits**: Unattended sleep terminations verify all target apps are completely closed before allowing your Mac to suspend.",
                "**Automatic Trash Cleanup**: Optionally empty the macOS Trash automatically when your Mac goes to sleep alongside closing open apps.",
                "**Window Placement Memory**: Remembers your preferred Settings window position so it stays right where you placed it."
            ])
        ]),

        ReleaseChangelog("1.1.4", "Battery health diagnostics & smoother popovers", [
            ("New Features", [
                "**Comprehensive Battery Health Diagnostics**: Check real-time wattage draw, temperature, cycle counts, maximum health capacity, and smart charging status.",
                "**Smart Power Throttling**: Automatically cuts background monitoring frequency in half when running on battery power to maximize battery longevity."
            ]),
            ("Improvements", [
                "**Smooth Visuals**: Refined drop shadows and corner smoothing across all menu bar panels to eliminate visual flicker.",
                "**Reliable Process Matching**: More precise app identification prevents confusion between main apps and similarly named background helpers."
            ])
        ]),

        ReleaseChangelog("1.1.2", "Dedicated stat panels & unified terminology", [
            ("New Features", [
                "**Dedicated Stat Panels**: Clicking CPU, Memory, GPU, or Battery opens a focused panel positioned directly beneath that specific menu bar item."
            ]),
            ("Improvements", [
                "**Unified Terminology**: Swapped all legacy RAM labels across the interface for clear, consistent Memory branding.",
                "**Responsive Hit-Testing**: Expanded click target shapes across all settings radio buttons and switches for effortless clicking."
            ])
        ]),

        ReleaseChangelog("1.1.1", "Battery monitoring & enhanced system protection", [
            ("New Features", [
                "**Menu Bar Battery Monitoring**: Added real-time battery percentage readout and charging indicator directly in your menu bar."
            ]),
            ("Improvements", [
                "**Intelligent App Protection**: Automatically safeguards essential macOS system components while allowing user utilities to be safely managed.",
                "**Reliable App Tracking**: Accurately tracks restored or unparented workspace apps to ensure dependable management."
            ])
        ]),

        ReleaseChangelog("1.1.0", "Liquid Glass appearance theme & Smart Rescue", [
            ("New Features", [
                "**macOS Liquid Glass Theme**: Translucent frosted materials and dynamic glass styling crafted specifically for modern macOS desktop aesthetics.",
                "**Smart Rescue Safeguards**: Protects your system during intense CPU or memory spikes by gently evicting idle background apps — never touching your active frontmost window.",
                "**Dedicated Automation Tab**: Centralized hub for sleep cleanup hours, inactivity timers, and resource threshold configuration."
            ]),
            ("Improvements", [
                "**Recently Quit Relaunch**: Fast access to relaunch your 5 most recently quit apps with a single click from the gear menu.",
                "**Interactive Inline Steppers**: Effortlessly tune CPU percentages and memory gigabytes with tactile stepper controls."
            ])
        ]),

        ReleaseChangelog("1.0.0", "Initial launch of QuitX for macOS", [
            ("New Features", [
                "**One-Click Batch Quit**: Instantly select and terminate multiple background apps at once to free up system resources.",
                "**Inactivity Auto-Quit**: Keep your Mac snappy by automatically closing applications left abandoned in the background.",
                "**Global Hotkey Triggers**: Open QuitX or fire quick quit actions from anywhere using customizable keyboard shortcuts.",
                "**Custom App Exclusions**: Mark critical tools, music players, and browsers as protected so they never get closed by accident."
            ])
        ])
    ]
}
