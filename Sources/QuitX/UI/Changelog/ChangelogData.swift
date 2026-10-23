import Foundation

extension ChangelogProvider {
    static let appReleases: [ReleaseChangelog] = [
        ReleaseChangelog("1.1.9", "In-app updates, What's New redesign & settings polish", [
            ("New Features", [
                "**Updates Straight From GitHub**: QuitX now checks this project's GitHub Releases directly. No update server, no keys, nothing else in between.",
                "**Update in the Menu**: When a new version ships, the menu bar icon gets a red dot and both menus offer Update or Restart to Update at the top.",
                "**Automatic Update Settings**: Settings ▸ General lets you turn automatic checks on or off and have new versions download and verify in the background."
            ]),
            ("Improvements", [
                "**Refined What's New Experience**: Compact welcome-style view focusing on the latest release, with quick sidebar access to browse previous version notes.",
                "**Playful Settings Tooltips**: Added humorous tooltips and icons across Shortcuts, Exclusions, General, and About tabs.",
                "**One-Line Terminal Installer**: Fast installation via `curl -fsSL https://quitx.kiron.dev/install | bash` with checksum verification and version checks."
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
                "**Accurate Multi-Window Tracking**: Queries macOS WindowServer across all virtual displays so multi-window apps remain safely open until their final window closes.",
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
                "**Deep Helper Process Termination**: Quitting complex multi-process apps like **Discord**, **Docker**, **Telegram**, or **Slack** cleanly shuts down all background helpers and orphan daemons in one go.",
                "**Zero-Lag Background Stats**: Offloaded menu bar telemetry sampling to background threads, eliminating UI hitching and stutter.",
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
                "**Native Kernel CPU Sampling**: Replaced subprocess invocations with direct kernel Mach task queries, slashing sampling overhead from 90ms down to under 2ms.",
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
                "**Smooth Visual Compositing**: Standardized drop shadows, corner smoothing, and layer invalidation across all menu bar status popovers to eliminate visual flicker.",
                "**Robust Process Tree Matching**: Enforced exact bundle ID verification to prevent prefix overlap collisions with background helper daemons."
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
                "**PID Recovery for Workspace Apps**: Resolves process IDs for recovered or unparented applications to guarantee reliable tracking."
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
