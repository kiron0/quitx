import Testing
import Foundation
import Darwin
import CoreGraphics
@testable import QuitX

@Suite("App Instance and Profile Tests")
@MainActor
struct AppInstanceTests {

    private func procargs(argc: Int32, exec: String, args: [String], padding: Int = 3) -> [UInt8] {
        var bytes = withUnsafeBytes(of: argc) { Array($0) }
        bytes += Array(exec.utf8) + [UInt8](repeating: 0, count: padding)
        for arg in args { bytes += Array(arg.utf8) + [0] }
        bytes += Array("PATH=/usr/bin".utf8) + [0]
        return bytes
    }

    @Test("KERN_PROCARGS2 parsing returns argv and ignores environment")
    func parsesProcargs() {
        let buffer = procargs(argc: 3, exec: "/Applications/A.app/Contents/MacOS/A", args: ["A", "--user-data-dir=/tmp/x", "-v"])
        #expect(ProcessArguments.parse(procargs: buffer) == ["A", "--user-data-dir=/tmp/x", "-v"])
    }

    @Test("Malformed procargs buffers are rejected or truncated safely")
    func rejectsMalformedProcargs() {
        #expect(ProcessArguments.parse(procargs: []) == nil)
        #expect(ProcessArguments.parse(procargs: [1, 0]) == nil)
        #expect(ProcessArguments.parse(procargs: procargs(argc: 0, exec: "/x", args: [])) == nil)
        #expect(ProcessArguments.parse(procargs: procargs(argc: -5, exec: "/x", args: ["a"])) == nil)
        #expect(ProcessArguments.parse(procargs: procargs(argc: 99_999, exec: "/x", args: ["a"])) == nil)
        let truncated = Array(procargs(argc: 4, exec: "/x", args: ["a", "b"]).dropLast(16))
        let parsed = ProcessArguments.parse(procargs: truncated) ?? []
        #expect(parsed.count <= 4)
        #expect(parsed.first == "a")
    }

    @Test("Reading argv of this process works and invalid PIDs fail")
    func readsOwnArguments() {
        let own = ProcessArguments.read(pid: ProcessInfo.processInfo.processIdentifier)
        #expect(own?.isEmpty == false)
        #expect(ProcessArguments.read(pid: -1) == nil)
        #expect(ProcessArguments.read(pid: 0) == nil)
    }

    @Test("Descendant check walks parents and stops on cycles and launchd")
    func descendantCheck() {
        let parents: [pid_t: pid_t] = [300: 200, 200: 100, 100: 1, 50: 50]
        let lookup: (pid_t) -> pid_t? = { parents[$0] }
        #expect(ProcessTree.isDescendant(300, ofAny: [100], parent: lookup))
        #expect(ProcessTree.isDescendant(300, ofAny: [200], parent: lookup))
        #expect(!ProcessTree.isDescendant(300, ofAny: [999], parent: lookup))
        #expect(!ProcessTree.isDescendant(50, ofAny: [7], parent: lookup))
        #expect(!ProcessTree.isDescendant(300, ofAny: [], parent: lookup))
        #expect(!ProcessTree.isDescendant(1, ofAny: [1], parent: lookup))
        #expect(!ProcessTree.isDescendant(404, ofAny: [100], parent: lookup))
    }

    @Test("Real process tree reports this process's parent and start time")
    func realProcessTree() {
        let pid = ProcessInfo.processInfo.processIdentifier
        #expect(ProcessTree.parentPid(of: pid) == getppid())
        #expect(ProcessTree.isDescendant(pid, ofAny: [getppid()]))
        #expect((ProcessTree.startTime(of: pid) ?? 0) > 0)
        #expect(ProcessTree.startTime(of: -1) == nil)
    }

    @Test("Instance labels come from Chromium, Firefox and generic profile flags")
    func instanceLabels() {
        #expect(AppInstanceLabel.label(arguments: ["Chrome", "--profile-directory=Profile 2"]) == "Profile 2")
        #expect(AppInstanceLabel.label(arguments: ["Chrome", "--user-data-dir=/Users/me/ChromeWork/"]) == "ChromeWork")
        #expect(AppInstanceLabel.label(arguments: ["Chrome", "--user-data-dir", "\"/tmp/Dev Data\""]) == "Dev Data")
        #expect(AppInstanceLabel.label(arguments: ["firefox", "-P", "work"]) == "work")
        #expect(AppInstanceLabel.label(arguments: ["firefox", "-profile", "/p/abc.default"]) == "abc.default")
        #expect(AppInstanceLabel.label(arguments: ["firefox", "-P", "--new-window"]) == nil)
        #expect(AppInstanceLabel.label(arguments: ["App", "-psn_0_1234"]) == nil)
        #expect(AppInstanceLabel.label(arguments: ["App"]) == nil)
        #expect(AppInstanceLabel.label(arguments: []) == nil)
        #expect(AppInstanceLabel.label(arguments: ["Chrome", "--profile-directory="]) == nil)
        #expect(AppInstanceLabel.label(arguments: ["-P", "x"]) == nil)
    }

    @Test("Chromium resolver wins over raw directory names")
    func resolverPrecedence() {
        let label = AppInstanceLabel.label(arguments: ["Chrome", "--user-data-dir=/d", "--profile-directory=Profile 1"]) { dir, profile in
            dir == "/d" && profile == "Profile 1" ? "Work" : nil
        }
        #expect(label == "Work")
        let fallback = AppInstanceLabel.label(arguments: ["Chrome", "--user-data-dir=/d", "--profile-directory=Profile 1"]) { _, _ in nil }
        #expect(fallback == "Profile 1")
    }

    @Test("Instances of one bundle merge into one row; others stay apart")
    func mergeInstances() {
        let apps = [
            AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: 10, windowCount: 2, memoryBytes: 100, cpuUsage: 1),
            AppInfo(name: "Notes", bundleId: "com.apple.Notes", pid: 20),
            AppInfo(name: "Chrome", bundleId: "com.google.chrome", pid: 11, windowCount: 3, memoryBytes: 50, cpuUsage: 2, isUnresponsive: true),
            AppInfo(name: "Helper", bundleId: "com.google.Chrome", pid: 30, isBackground: true),
            AppInfo(name: "Tool", pid: 40),
            AppInfo(name: "Tool", pid: 41),
            AppInfo(name: "Trash", bundleId: "trash", pid: nil, pids: [])
        ]
        let merged = AppInstanceGrouping.merge(apps)
        #expect(merged.map(\.name) == ["Chrome", "Notes", "Helper", "Tool", "Tool", "Trash"])
        let chrome = merged[0]
        #expect(chrome.id == "app:com.google.chrome")
        #expect(chrome.pids == [10, 11])
        #expect(chrome.pid == 10)
        #expect(chrome.windowCount == 5)
        #expect(chrome.memoryBytes == 150)
        #expect(chrome.cpuUsage == 3)
        #expect(chrome.isUnresponsive)
        #expect(merged[1].id == "app:com.apple.notes")
        #expect(merged[2].isBackground)
        #expect(Set(merged.map(\.id)).count == merged.count)
    }

    @Test("Merged row ID stays stable when instances come and go")
    func mergedIdStable() {
        let one = AppInstanceGrouping.merge([AppInfo(name: "Code", bundleId: "com.microsoft.VSCode", pid: 5)])
        let two = AppInstanceGrouping.merge([
            AppInfo(name: "Code", bundleId: "com.microsoft.VSCode", pid: 5),
            AppInfo(name: "Code", bundleId: "com.microsoft.VSCode", pid: 6)
        ])
        #expect(one.first?.id == two.first?.id)
        #expect(AppInstanceGrouping.merge([]).isEmpty)
    }

    @Test("Instance labels are unique and fall back to PID")
    func uniqueInstanceLabels() {
        let labels = AppInstanceLabel.uniqueLabels(pids: [10, 11, 12, 13]) { pid in
            [10: "Work", 11: "Work", 13: "Home"][pid]
        }
        #expect(labels == [10: "Work · PID 10", 11: "Work · PID 11", 12: "PID 12", 13: "Home"])
        #expect(AppInstanceLabel.uniqueLabels(pids: []) { _ in "x" }.isEmpty)
    }

    @Test("Live stats keep every instance PID of a merged row")
    func liveStatsKeepMergedPids() async {
        let pid = ProcessInfo.processInfo.processIdentifier
        let parent = getppid()
        let row = AppInfo(id: "app:x", name: "X", bundleId: "x", pid: pid, pids: [pid, parent, 999_999])
        let updated = await AppListService.shared.fetchLiveStats(currentApps: [row], config: .default)
        #expect(updated.first?.pids == [pid, parent])
        #expect(updated.first?.id == "app:x")
    }

    @Test("Window titles are trimmed and truncated")
    func displayTitles() {
        #expect(WindowGrouping.displayTitle("Inbox - Work") == "Inbox - Work")
        #expect(WindowGrouping.displayTitle("   ") == "Untitled Window")
        #expect(WindowGrouping.displayTitle("  Doc  ") == "Doc")
        let long = String(repeating: "a", count: 200)
        let shown = WindowGrouping.displayTitle(long, maxLength: 20)
        #expect(shown.count == 20)
        #expect(shown.hasSuffix("…"))
        #expect(WindowGrouping.displayTitle("abc", maxLength: 1).count <= 2)
    }

    @Test("Helpers of a sibling instance are never quit with this instance")
    func helperOwnership() {
        let parents: [pid_t: pid_t] = [501: 500, 601: 600, 700: 1]
        let descendant: (pid_t, Set<pid_t>) -> Bool = { pid, roots in
            ProcessTree.isDescendant(pid, ofAny: roots, parent: { parents[$0] })
        }
        #expect(QuitService.helperBelongsToTarget(pid: 700, targetPids: [500], siblingInstancePids: [], isDescendant: descendant))
        #expect(QuitService.helperBelongsToTarget(pid: 501, targetPids: [500], siblingInstancePids: [600], isDescendant: descendant))
        #expect(!QuitService.helperBelongsToTarget(pid: 601, targetPids: [500], siblingInstancePids: [600], isDescendant: descendant))
        #expect(!QuitService.helperBelongsToTarget(pid: 700, targetPids: [500], siblingInstancePids: [600], isDescendant: descendant))
        #expect(!QuitService.helperBelongsToTarget(pid: 600, targetPids: [500], siblingInstancePids: [600], isDescendant: descendant))
    }

    @Test("Quitting collects orphaned bundle helpers and, when forced, every spawned process")
    func helperProcessCollection() {
        let root = URL(fileURLWithPath: "/Applications/Editor.app")
        let parents: [pid_t: pid_t] = [501: 500, 502: 501, 503: 500, 700: 1, 800: 1, 900: 1]
        let paths: [pid_t: String] = [
            500: "/Applications/Editor.app/Contents/MacOS/Editor",
            501: "/Applications/Editor.app/Contents/Frameworks/Editor Helper (Plugin).app/Contents/MacOS/Editor Helper (Plugin)",
            502: "/Users/me/.editor/extensions/tool/bin/language-server",
            503: "/Users/me/Library/Application Support/Editor/EditorServer",
            700: "/Applications/Editor.app/Contents/Frameworks/Electron Framework.framework/Helpers/chrome_crashpad_handler",
            800: "/Applications/Other.app/Contents/MacOS/Other",
            900: "/Applications/Editor.app/Contents/MacOS/Editor"
        ]
        let descendant: (pid_t, Set<pid_t>) -> Bool = { pid, roots in
            ProcessTree.isDescendant(pid, ofAny: roots, parent: { parents[$0] })
        }
        let forced = QuitService.helperProcesses(
            targetPids: [500], siblingInstancePids: [], rootURL: root, processPaths: paths,
            includeOutsideBundle: true, ownPid: 999, isDescendant: descendant
        )
        #expect(Set(forced.keys) == [501, 502, 503, 700, 900])
        #expect(forced[502] == paths[502])

        let graceful = QuitService.helperProcesses(
            targetPids: [500], siblingInstancePids: [], rootURL: root, processPaths: paths,
            includeOutsideBundle: false, ownPid: 999, isDescendant: descendant
        )
        #expect(Set(graceful.keys) == [501, 700, 900])

        let withSibling = QuitService.helperProcesses(
            targetPids: [500], siblingInstancePids: [900], rootURL: root, processPaths: paths,
            includeOutsideBundle: true, ownPid: 999, isDescendant: descendant
        )
        #expect(Set(withSibling.keys) == [501, 502, 503])

        let skipsSelf = QuitService.helperProcesses(
            targetPids: [500], siblingInstancePids: [], rootURL: root, processPaths: paths,
            includeOutsideBundle: true, ownPid: 503, isDescendant: descendant
        )
        #expect(skipsSelf[503] == nil)
    }

    @Test("Restart keeps launch arguments without executable and psn flags")
    func relaunchArguments() {
        #expect(RestartService.relaunchArguments(from: ["/x/Chrome", "--user-data-dir=/d", "-psn_0_42"]) == ["--user-data-dir=/d"])
        #expect(RestartService.relaunchArguments(from: []) == [])
    }

    @Test("Restart relaunches each instance with its own arguments")
    func relaunchPlan() {
        #expect(RestartService.relaunchPlan(pids: [1]) { _ in ["x"] } == [nil])
        #expect(RestartService.relaunchPlan(pids: []) { _ in ["x"] } == [nil])
        let plan = RestartService.relaunchPlan(pids: [1, 2]) { pid in
            pid == 1 ? ["/x/App", "--user-data-dir=/a", "-psn_0_1"] : nil
        }
        #expect(plan == [["--user-data-dir=/a"], nil])
    }

    @Test("Windows menu appears only for more than one window")
    func windowsMenuVisibility() {
        #expect(!AppRowView.showsWindowsMenu(trusted: true, axWindowCount: 0, visibleWindowCount: 5))
        #expect(!AppRowView.showsWindowsMenu(trusted: true, axWindowCount: 1, visibleWindowCount: 5))
        #expect(AppRowView.showsWindowsMenu(trusted: true, axWindowCount: 2, visibleWindowCount: 0))
        #expect(!AppRowView.showsWindowsMenu(trusted: false, axWindowCount: 0, visibleWindowCount: 1))
        #expect(AppRowView.showsWindowsMenu(trusted: false, axWindowCount: 0, visibleWindowCount: 2))
    }

    @Test("Last-window quit ignores windows that only left the current Space")
    func remainingWindowsDecision() {
        func remaining(ax: Int?, all: Set<CGWindowID>?, seen: Set<CGWindowID> = [], closed: Set<CGWindowID> = [], user: Bool = false, known: Int = 0) -> Int? {
            LastWindowQuitWindowState.remainingWindows(axCount: ax, allSpacesIDs: all, seenIDs: seen, closedIDs: closed, closedByUser: user, knownWindows: known)
        }
        #expect(remaining(ax: 0, all: [1, 2, 3]) == 3)
        #expect(remaining(ax: 0, all: []) == 0)
        #expect(remaining(ax: 0, all: [7], user: true, known: 0) == 0)
        #expect(remaining(ax: 0, all: [7], user: true, known: 1) == 1)
        #expect(remaining(ax: 2, all: [], user: true) == 2)
        #expect(remaining(ax: nil, all: [], user: true) == nil)
        #expect(remaining(ax: 0, all: nil) == nil)
        var samples = 0
        for _ in 0..<10 {
            samples = LastWindowQuitWindowState.nextEmptySamples(windowCount: remaining(ax: 0, all: [1]), previous: samples)
        }
        #expect(samples == 0, "full-screen Space switch must never count as closed")
    }

    @Test("A window the user closed but the app only hid counts as closed")
    func hiddenOnCloseDecision() {
        func remaining(all: Set<CGWindowID>, seen: Set<CGWindowID>, closed: Set<CGWindowID>) -> Int? {
            LastWindowQuitWindowState.remainingWindows(axCount: 0, allSpacesIDs: all, seenIDs: seen, closedIDs: closed, closedByUser: true, knownWindows: 1)
        }
        #expect(remaining(all: [10, 99], seen: [10], closed: [10]) == 0, "Discord-style hide plus a never-shown helper window")
        #expect(remaining(all: [10, 11], seen: [10, 11], closed: [10]) == 1, "another real window remains")
        #expect(remaining(all: [10], seen: [10], closed: []) == 1)
        #expect(LastWindowQuitWindowState.remainingWindows(axCount: 1, allSpacesIDs: [10], seenIDs: [10], closedIDs: [10], closedByUser: true, knownWindows: 0) == 1)
    }

    @Test("Close-button hit testing is limited to the title bar's leading corner")
    func closeButtonRegion() {
        let window = CGRect(x: 100, y: 50, width: 800, height: 600)
        #expect(LastWindowQuitWindowState.isCloseButtonRegion(point: CGPoint(x: 112, y: 62), windowBounds: window))
        #expect(LastWindowQuitWindowState.isCloseButtonRegion(point: CGPoint(x: 196, y: 94), windowBounds: window))
        #expect(!LastWindowQuitWindowState.isCloseButtonRegion(point: CGPoint(x: 197, y: 62), windowBounds: window))
        #expect(!LastWindowQuitWindowState.isCloseButtonRegion(point: CGPoint(x: 112, y: 95), windowBounds: window))
        #expect(!LastWindowQuitWindowState.isCloseButtonRegion(point: CGPoint(x: 90, y: 62), windowBounds: window))
        #expect(!LastWindowQuitWindowCounter.isCloseButton(at: CGPoint(x: -10_000, y: -10_000)))
    }

    @Test("All-Spaces window count is readable for this process and invalid PIDs")
    func allSpacesCount() {
        #expect(LastWindowQuitWindowCounter.allSpacesWindowCount(for: -1) == 0)
        #expect(LastWindowQuitWindowCounter.allSpacesWindowIDs(for: -1) == [])
        #expect(LastWindowQuitWindowCounter.allSpacesWindowCount(for: ProcessInfo.processInfo.processIdentifier) != nil)
    }
}
