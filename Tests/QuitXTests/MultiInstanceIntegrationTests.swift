import AppKit
import Darwin
import Foundation
import Testing
@testable import QuitX

private let instanceFixtureApp = ProcessInfo.processInfo.environment["QUITX_INSTANCE_FIXTURE_APP"]

@Suite(
    "Multi Instance Integration Tests",
    .enabled(if: instanceFixtureApp != nil),
    .serialized
)
@MainActor
struct MultiInstanceIntegrationTests {
    private let bundleId = "com.quitx.tests.instance-fixture"

    private func launchInstance(app: URL, dataDir: String, refuseQuit: Bool = false) async throws -> pid_t {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.activates = false
        config.arguments = ["--user-data-dir=\(dataDir)"]
        if refuseQuit { config.environment = ["QUITX_FIXTURE_REFUSE_QUIT": "1"] }
        let running = try await NSWorkspace.shared.openApplication(at: app, configuration: config)
        return running.processIdentifier
    }

    private func waitUntil(timeout: TimeInterval, _ condition: @MainActor () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return await condition()
    }

    @Test("Two instances are labeled and quit independently")
    func instancesQuitIndependently() async throws {
        let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-instances-\(UUID().uuidString)")
        let dirA = root.appendingPathComponent("AlphaData").path
        let dirB = root.appendingPathComponent("BetaData").path

        let pidA = try await launchInstance(app: appURL, dataDir: dirA)
        let pidB = try await launchInstance(app: appURL, dataDir: dirB)
        defer {
            for pid in [pidA, pidB] where QuitService.processIsRunning(pid) {
                Darwin.kill(pid, SIGKILL)
            }
            try? FileManager.default.removeItem(at: root)
        }
        #expect(pidA != pidB)

        var config = QuitXConfig.default
        config.exclude = []
        config.perAppQuitRules = [:]

        var rows: [AppInfo] = []
        let listed = await waitUntil(timeout: 8) {
            rows = await AppListService.shared.fetchApps(config: config).filter { $0.bundleId == bundleId }
            return rows.count == 2
        }
        #expect(listed)
        guard listed else { return }

        let rowA = try #require(rows.first { $0.pid == pidA })
        let rowB = try #require(rows.first { $0.pid == pidB })
        #expect(rowA.instanceLabel == "AlphaData")
        #expect(rowB.instanceLabel == "BetaData")
        #expect(rowA.id != rowB.id)
        #expect(rowA.displayName != rowB.displayName)

        let results = await QuitService.shared.quit(apps: [rowA], force: false)
        #expect(results.first?.success == true)

        let aGone = await waitUntil(timeout: 6) { !QuitService.processIsRunning(pidA) }
        #expect(aGone)
        #expect(QuitService.processIsRunning(pidB), "quitting one instance must not touch its sibling")

        let afterQuit = await AppListService.shared.fetchApps(config: config).filter { $0.bundleId == bundleId }
        #expect(afterQuit.map(\.pid) == [pidB])
        #expect(afterQuit.first?.instanceLabel == nil, "a single remaining instance needs no label")

        let pidA2 = try await launchInstance(app: appURL, dataDir: dirA)
        defer { if QuitService.processIsRunning(pidA2) { Darwin.kill(pidA2, SIGKILL) } }
        var labeledB: AppInfo?
        let relisted = await waitUntil(timeout: 8) {
            let current = await AppListService.shared.fetchApps(config: config).filter { $0.bundleId == bundleId }
            labeledB = current.first { $0.pid == pidB }
            return current.count == 2 && labeledB?.instanceLabel == "BetaData"
        }
        #expect(relisted)
        guard relisted, let restartTarget = labeledB else { return }
        #expect(await RestartService.shared.restart(app: restartTarget))
        var restartedB: pid_t?
        let cameBack = await waitUntil(timeout: 8) {
            let current = await AppListService.shared.fetchApps(config: config).filter { $0.bundleId == bundleId }
            restartedB = current.first { $0.instanceLabel == "BetaData" }?.pid
            return current.count == 2 && restartedB != nil && restartedB != pidB
        }
        #expect(cameBack)
        #expect(QuitService.processIsRunning(pidA2))
        #expect(!QuitService.processIsRunning(pidB))
        if let restartedB {
            defer { if QuitService.processIsRunning(restartedB) { Darwin.kill(restartedB, SIGKILL) } }
            let args = ProcessArguments.read(pid: restartedB) ?? []
            #expect(args.contains("--user-data-dir=\(dirB)"))
        }

        let forced = await QuitService.shared.quit(apps: [rowB], force: true)
        #expect(forced.first?.success == true)
        let bGone = await waitUntil(timeout: 6) { !QuitService.processIsRunning(pidB) }
        #expect(bGone)
    }

    @Test(
        "Window control lists, shows and closes a real window",
        .enabled(if: AXIsProcessTrusted())
    )
    func windowControl() async throws {
        let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-win-\(UUID().uuidString)").path
        let pid = try await launchInstance(app: appURL, dataDir: dir)
        defer { if QuitService.processIsRunning(pid) { Darwin.kill(pid, SIGKILL) } }

        var windows: [AppWindowControl.Window] = []
        let found = await waitUntil(timeout: 8) {
            windows = AppWindowControl.windows(pid: pid)
            return windows.count == 1
        }
        #expect(found)
        guard found else { return }
        #expect(windows[0].title == "QuitX Last Window Integration Fixture")
        #expect(ChromiumProfiles.profileNames(pid: pid).isEmpty)

        #expect(AppWindowControl.close(windows) == 1)
        let closed = await waitUntil(timeout: 4) { AppWindowControl.windows(pid: pid).isEmpty }
        #expect(closed)
        #expect(QuitService.processIsRunning(pid), "closing windows must not quit the app")
        #expect(AppWindowControl.windows(pid: -1).isEmpty)
    }

    @Test("Normal quit of an app that refuses never escalates; force quit wins")
    func normalQuitNeverEscalates() async throws {
        let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-refuse-\(UUID().uuidString)").path
        let pid = try await launchInstance(app: appURL, dataDir: dir, refuseQuit: true)
        defer { if QuitService.processIsRunning(pid) { Darwin.kill(pid, SIGKILL) } }

        var config = QuitXConfig.default
        config.exclude = []
        var row: AppInfo?
        let listed = await waitUntil(timeout: 8) {
            row = await AppListService.shared.fetchApps(config: config).first { $0.pid == pid }
            return row != nil
        }
        #expect(listed)
        guard let row else { return }

        let normal = await QuitService.shared.quit(apps: [row], force: false)
        #expect(normal.first?.success == false)
        #expect(normal.first?.forced == false)
        try? await Task.sleep(for: .seconds(1))
        #expect(QuitService.processIsRunning(pid), "normal quit must never escalate to force")

        let forced = await QuitService.shared.quit(apps: [row], force: true)
        #expect(forced.first?.success == true)
        #expect(!QuitService.processIsRunning(pid))
    }
}
