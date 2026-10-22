import Testing
import Foundation
import Darwin
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

    @Test("Open file listing includes a file this process holds open")
    func openFilesIncludesHeldFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-openfile-\(UUID().uuidString)")
        try Data("x".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let paths = OpenFiles.paths(pid: ProcessInfo.processInfo.processIdentifier)
        let target = url.resolvingSymlinksInPath().path
        #expect(paths.contains { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path == target })
        #expect(OpenFiles.paths(pid: -1).isEmpty)
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

    @Test("Only apps running more than once get labels; collisions fall back to PID")
    func assignLabels() {
        let apps = [
            AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: 10),
            AppInfo(name: "Chrome", bundleId: "com.google.chrome", pid: 11),
            AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: 12),
            AppInfo(name: "Notes", bundleId: "com.apple.Notes", pid: 20),
            AppInfo(name: "Helper", bundleId: "com.google.Chrome", pid: 30, isBackground: true),
            AppInfo(name: "Tool", pid: 40),
            AppInfo(name: "Tool", pid: 41)
        ]
        let labels: [pid_t: String] = [10: "Work", 11: "Work", 40: "A"]
        let result = AppInstanceLabel.assign(apps) { labels[$0] }
        #expect(result[0].instanceLabel == "Work · PID 10")
        #expect(result[1].instanceLabel == "Work · PID 11")
        #expect(result[2].instanceLabel == "PID 12")
        #expect(result[3].instanceLabel == nil)
        #expect(result[4].instanceLabel == nil)
        #expect(result[5].instanceLabel == "A")
        #expect(result[6].instanceLabel == "PID 41")
        #expect(result.map(\.id) == apps.map(\.id))
        #expect(result.map(\.name) == apps.map(\.name))
        let unique = Set(result.prefix(3).map(\.displayName))
        #expect(unique.count == 3)
    }

    @Test("Display name, copies and live stats keep the instance label")
    func labelSurvivesCopies() async {
        let pid = ProcessInfo.processInfo.processIdentifier
        let app = AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: pid, instanceLabel: "Work")
        #expect(app.displayName == "Chrome — Work")
        #expect(AppInfo(name: "Chrome").displayName == "Chrome")
        #expect(AppInfo(name: "Chrome", instanceLabel: "").displayName == "Chrome")
        #expect(app.settingUnresponsive(true).instanceLabel == "Work")
        #expect(app.settingInstanceLabel(nil).instanceLabel == nil)
        let updated = await AppListService.shared.fetchLiveStats(currentApps: [app], config: .default)
        #expect(updated.first?.instanceLabel == "Work")
    }

    private func makeUserDataDir(_ json: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-chromium-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: dir.appendingPathComponent("Local State"))
        return dir
    }

    @Test("Local State parsing reads profile names and tolerates junk")
    func parsesLocalState() {
        let json = #"{"profile":{"info_cache":{"Profile 1":{"name":"Work"},"Default":{"name":"Personal"},"Profile 2":{"name":"  "},"Bad":3}}}"#
        let profiles = ChromiumProfiles.parseLocalState(Data(json.utf8))
        #expect(profiles.map(\.directory) == ["Default", "Profile 1", "Profile 2"])
        #expect(profiles.map(\.name) == ["Personal", "Work", "Profile 2"])
        #expect(ChromiumProfiles.parseLocalState(Data("not json".utf8)).isEmpty)
        #expect(ChromiumProfiles.parseLocalState(Data("[]".utf8)).isEmpty)
        #expect(ChromiumProfiles.parseLocalState(Data(#"{"profile":{}}"#.utf8)).isEmpty)
    }

    @Test("Profiles reload when Local State changes and resolve labels")
    func profilesFromDisk() throws {
        let dir = try makeUserDataDir(#"{"profile":{"info_cache":{"Default":{"name":"Solo"}}}}"#)
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(ChromiumProfiles.profiles(userDataDir: dir).map(\.name) == ["Solo"])
        #expect(ChromiumProfiles.resolveLabel(userDataDir: dir.path, profileDirectory: nil) == "Solo")
        #expect(ChromiumProfiles.resolveLabel(userDataDir: dir.path, profileDirectory: "Missing") == nil)
        #expect(ChromiumProfiles.resolveLabel(userDataDir: nil, profileDirectory: "Default") == nil)

        let localState = dir.appendingPathComponent("Local State")
        try Data(#"{"profile":{"info_cache":{"Default":{"name":"A"},"Profile 1":{"name":"B"}}}}"#.utf8).write(to: localState)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: localState.path)
        #expect(ChromiumProfiles.profiles(userDataDir: dir).map(\.name) == ["A", "B"])
        #expect(ChromiumProfiles.resolveLabel(userDataDir: dir.path, profileDirectory: "Profile 1") == "B")
        #expect(ChromiumProfiles.resolveLabel(userDataDir: dir.path, profileDirectory: nil) == nil)
        #expect(ChromiumProfiles.profiles(userDataDir: dir.appendingPathComponent("nope")).isEmpty)
    }

    @Test("User data directory is found from an open file in a profile folder")
    func userDataDirFromOpenFile() throws {
        let dir = try makeUserDataDir(#"{"profile":{"info_cache":{}}}"#)
        defer { try? FileManager.default.removeItem(at: dir) }
        let profileDir = dir.appendingPathComponent("Default", isDirectory: true)
        try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
        let history = profileDir.appendingPathComponent("History")
        try Data("db".utf8).write(to: history)
        let handle = try FileHandle(forReadingFrom: history)
        defer { try? handle.close() }

        let explicit = ChromiumProfiles.userDataDirectory(pid: -42, arguments: ["x", "--user-data-dir=\(dir.path)"])
        #expect(explicit?.resolvingSymlinksInPath().path == dir.resolvingSymlinksInPath().path)

        let pid = ProcessInfo.processInfo.processIdentifier
        let found = ChromiumProfiles.userDataDirectory(pid: pid, arguments: ["x"])
        #expect(found?.resolvingSymlinksInPath().path == dir.resolvingSymlinksInPath().path)
    }

    @Test("Windows group by trailing profile name, longest name first")
    func groupsWindows() {
        let titles = [
            "Inbox - Gmail - Work",
            "Docs - Work Team",
            "News - Personal",
            "Settings",
            "Work"
        ]
        let groups = WindowGrouping.groups(titles: titles, profileNames: ["Work", "Personal", "Work Team", "Work"])
        #expect(groups == [
            .init(name: "Work", indices: [0, 4]),
            .init(name: "Work Team", indices: [1]),
            .init(name: "Personal", indices: [2]),
            .init(name: WindowGrouping.otherGroupName, indices: [3])
        ])
    }

    @Test("No grouping with one profile or when no title carries a profile")
    func noGrouping() {
        #expect(WindowGrouping.groups(titles: ["A - Solo"], profileNames: ["Solo"]) == nil)
        #expect(WindowGrouping.groups(titles: ["A", "B"], profileNames: ["X", "Y"]) == nil)
        #expect(WindowGrouping.groups(titles: [], profileNames: ["X", "Y"]) == nil)
        #expect(WindowGrouping.groups(titles: ["A - X"], profileNames: ["", "X"]) == nil)
        #expect(WindowGrouping.groups(titles: ["A – X", "B — Y"], profileNames: ["X", "Y"])?.count == 2)
    }

    @Test("Window titles drop the profile suffix and are truncated")
    func displayTitles() {
        #expect(WindowGrouping.displayTitle("Inbox - Work", profile: "Work") == "Inbox")
        #expect(WindowGrouping.displayTitle("Inbox - Work", profile: nil) == "Inbox - Work")
        #expect(WindowGrouping.displayTitle("   ", profile: nil) == "Untitled Window")
        #expect(WindowGrouping.displayTitle(" - Work", profile: "Work") == "Untitled Window")
        let long = String(repeating: "a", count: 200)
        let shown = WindowGrouping.displayTitle(long, profile: nil, maxLength: 20)
        #expect(shown.count == 20)
        #expect(shown.hasSuffix("…"))
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

    @Test("Restart keeps launch arguments without executable and psn flags")
    func relaunchArguments() {
        #expect(RestartService.relaunchArguments(from: ["/x/Chrome", "--user-data-dir=/d", "-psn_0_42"]) == ["--user-data-dir=/d"])
        #expect(RestartService.relaunchArguments(from: []) == [])
    }

    @Test("Search matches the instance label")
    func searchMatchesLabel() {
        let vm = AppListViewModel()
        vm.apps = [
            AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: 1, instanceLabel: "Work"),
            AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: 2, instanceLabel: "Personal")
        ]
        vm.searchQuery = "work"
        #expect(vm.filteredApps.map(\.pid) == [1])
        vm.searchQuery = "chrome"
        #expect(vm.filteredApps.count == 2)
    }

    @Test("Windows menu appears only for more than one window")
    func windowsMenuVisibility() {
        #expect(!AppRowView.showsWindowsMenu(trusted: true, axWindowCount: 0, visibleWindowCount: 5))
        #expect(!AppRowView.showsWindowsMenu(trusted: true, axWindowCount: 1, visibleWindowCount: 5))
        #expect(AppRowView.showsWindowsMenu(trusted: true, axWindowCount: 2, visibleWindowCount: 0))
        #expect(!AppRowView.showsWindowsMenu(trusted: false, axWindowCount: 0, visibleWindowCount: 1))
        #expect(AppRowView.showsWindowsMenu(trusted: false, axWindowCount: 0, visibleWindowCount: 2))
    }
}
