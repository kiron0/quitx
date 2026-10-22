import AppKit
import Darwin
import Foundation
import Testing
@testable import QuitX

private let instanceFixtureApp = ProcessInfo.processInfo.environment["QUITX_INSTANCE_FIXTURE_APP"]

extension GUIIntegrationTests {
    @Suite(
        "Multi Instance Integration Tests",
        .enabled(if: instanceFixtureApp != nil),
        .serialized
    )
    @MainActor
    struct MultiInstanceIntegrationTests {
        private let bundleId = "com.quitx.tests.instance-fixture"

        private func launchInstance(
            app: URL,
            dataDir: String,
            refuseQuit: Bool = false,
            spawnBackend: Bool = false,
            accessoryOnClose: Bool = false,
            stateFile: URL? = nil
        ) async throws -> pid_t {
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            config.activates = false
            config.arguments = ["--user-data-dir=\(dataDir)"]
            var environment: [String: String] = [
                "QUITX_FIXTURE_QUIT_SENDER": String(ProcessInfo.processInfo.processIdentifier)
            ]
            if refuseQuit { environment["QUITX_FIXTURE_REFUSE_QUIT"] = "1" }
            if spawnBackend { environment["QUITX_FIXTURE_SPAWN_BACKEND"] = "1" }
            if accessoryOnClose { environment["QUITX_FIXTURE_ACCESSORY_ON_CLOSE"] = "1" }
            if let stateFile { environment["QUITX_FIXTURE_STATE_FILE"] = stateFile.path }
            config.environment = environment
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

        private var listConfig: QuitXConfig {
            var config = QuitXConfig.default
            config.exclude = []
            config.perAppQuitRules = [:]
            return config
        }

        private func fixtureRows() async -> [AppInfo] {
            await AppListService.shared.fetchApps(config: listConfig).filter { $0.bundleId == bundleId }
        }

        private func backendPid(of parent: pid_t, app: URL) -> pid_t? {
            let contents = app.resolvingSymlinksInPath().appendingPathComponent("Contents").path + "/"
            return AppListService.runningProcessPaths().first { pid, path in
                URL(fileURLWithPath: path).resolvingSymlinksInPath().path.hasPrefix(contents)
                    && pid != parent
                    && ProcessTree.parentPid(of: pid) == parent
            }?.key
        }

        private func kill(_ pids: [pid_t?]) {
            for case let pid? in pids where QuitService.processIsRunning(pid) {
                Darwin.kill(pid, SIGKILL)
            }
        }

        @Test("Instances share one row and quitting the row quits every instance")
        func oneRowQuitsAllInstances() async throws {
            let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-instances-\(UUID().uuidString)")
            let pidA = try await launchInstance(app: appURL, dataDir: root.appendingPathComponent("AlphaData").path)
            let pidB = try await launchInstance(app: appURL, dataDir: root.appendingPathComponent("BetaData").path)
            defer { kill([pidA, pidB]) }

            var rows: [AppInfo] = []
            let listed = await waitUntil(timeout: 8) {
                rows = await fixtureRows()
                return rows.count == 1 && Set(rows[0].pids) == [pidA, pidB]
            }
            #expect(listed)
            guard listed, let row = rows.first else { return }
            #expect(row.id == "app:\(bundleId)")

            let results = await QuitService.shared.quit(apps: [row], force: false)
            #expect(results.first?.success == true)
            let gone = await waitUntil(timeout: 6) {
                !QuitService.processIsRunning(pidA) && !QuitService.processIsRunning(pidB)
            }
            #expect(gone)
            #expect(await fixtureRows().isEmpty)
        }

        @Test("Restarting the row brings every instance back with its arguments")
        func restartKeepsInstances() async throws {
            let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-restart-\(UUID().uuidString)")
            let dirA = root.appendingPathComponent("AlphaData").path
            let dirB = root.appendingPathComponent("BetaData").path
            let pidA = try await launchInstance(app: appURL, dataDir: dirA)
            let pidB = try await launchInstance(app: appURL, dataDir: dirB)
            var restarted: [pid_t] = []
            defer { kill([pidA, pidB] + restarted.map { Optional($0) }) }

            var row: AppInfo?
            let listed = await waitUntil(timeout: 8) {
                row = await fixtureRows().first
                return row.map { Set($0.pids) == [pidA, pidB] } ?? false
            }
            #expect(listed)
            guard listed, let row else { return }

            #expect(await RestartService.shared.restart(app: row))
            let cameBack = await waitUntil(timeout: 8) {
                let pids = await fixtureRows().first?.pids ?? []
                restarted = pids
                return pids.count == 2 && Set(pids).isDisjoint(with: [pidA, pidB])
            }
            #expect(cameBack)
            let arguments = restarted.flatMap { ProcessArguments.read(pid: $0) ?? [] }
            #expect(arguments.contains("--user-data-dir=\(dirA)"))
            #expect(arguments.contains("--user-data-dir=\(dirB)"))
        }

        private func makeService(states: [pid_t: URL], restrictedTo pid: pid_t) -> LastWindowQuitService {
            LastWindowQuitService(
                restrictedToPID: pid,
                recordsRecentlyQuit: false,
                requiresAccessibilityTrust: false,
                windowCount: { requested in
                    guard let url = states[requested] else { return 0 }
                    guard let state = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                    return state == "closed" ? 0 : 1
                }
            )
        }

        private func enableLastWindowQuit() -> QuitXConfig {
            let original = ConfigStore.shared.config
            var config = original
            config.quitWhenLastWindowClosed = true
            config.exclude = []
            config.neverQuitMusic = false
            config.perAppQuitRules = [:]
            ConfigStore.shared.config = config
            return original
        }

        @Test("Closing one instance's window keeps the app while another window is open")
        func lastWindowWaitsForEveryWindow() async throws {
            let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-lastwin-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let stateA = root.appendingPathComponent("stateA")
            let stateB = root.appendingPathComponent("stateB")
            let pidA = try await launchInstance(app: appURL, dataDir: root.appendingPathComponent("A").path, stateFile: stateA)
            let pidB = try await launchInstance(app: appURL, dataDir: root.appendingPathComponent("B").path, stateFile: stateB)
            let service = makeService(states: [pidA: stateA, pidB: stateB], restrictedTo: pidA)
            let original = enableLastWindowQuit()
            defer {
                service.stop()
                ConfigStore.shared.config = original
                kill([pidA, pidB])
                try? FileManager.default.removeItem(at: root)
            }

            let visible = await waitUntil(timeout: 8) {
                let ids = LastWindowQuitWindowCounter.visibleWindowIDs() ?? [:]
                return !(ids[pidA] ?? []).isEmpty && !(ids[pidB] ?? []).isEmpty
            }
            #expect(visible)
            guard visible else { return }
            service.start()
            let tracking = await waitUntil(timeout: 4) { service.isTracking(pidA) && service.isTracking(pidB) }
            #expect(tracking)
            guard tracking else { return }

            #expect(Darwin.kill(pidA, SIGUSR1) == 0)
            let closedA = await waitUntil(timeout: 4) {
                (try? String(contentsOf: stateA, encoding: .utf8)) == "closed"
            }
            #expect(closedA)
            try? await Task.sleep(for: .seconds(4))
            #expect(service.quitRequests.isEmpty, "a window is still open, so nothing quits")
            #expect(QuitService.processIsRunning(pidB))

            #expect(Darwin.kill(pidB, SIGUSR1) == 0)
            let allGone = await waitUntil(timeout: 10) {
                !QuitService.processIsRunning(pidA) && !QuitService.processIsRunning(pidB)
            }
            #expect(allGone, "the last window closed, so every instance quits")
            #expect(service.quitRequests.count == 1)
            #expect(Set(service.quitRequests.first ?? []) == [pidA, pidB])
        }

        @Test("App that hides its Dock icon on close still quits with its backend")
        func dockerStyleQuitsWithBackend() async throws {
            let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-docker-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let state = root.appendingPathComponent("state")
            let pid = try await launchInstance(
                app: appURL,
                dataDir: root.appendingPathComponent("D").path,
                spawnBackend: true,
                accessoryOnClose: true,
                stateFile: state
            )
            var backend: pid_t?
            let service = makeService(states: [pid: state], restrictedTo: pid)
            let original = enableLastWindowQuit()
            defer {
                service.stop()
                ConfigStore.shared.config = original
                kill([pid, backend])
                try? FileManager.default.removeItem(at: root)
            }

            let ready = await waitUntil(timeout: 8) {
                backend = backendPid(of: pid, app: appURL)
                return backend != nil && !(LastWindowQuitWindowCounter.visibleWindowIDs()?[pid] ?? []).isEmpty
            }
            #expect(ready)
            guard ready, let backend else { return }
            service.start()
            let tracking = await waitUntil(timeout: 4) { service.isTracking(pid) }
            #expect(tracking)
            guard tracking else { return }

            #expect(Darwin.kill(pid, SIGUSR1) == 0)
            let allGone = await waitUntil(timeout: 10) {
                !QuitService.processIsRunning(pid) && !QuitService.processIsRunning(backend)
            }
            #expect(allGone, "windowless app quits completely, backend included")
        }

        @Test("Single instance quit takes its backend child processes with it")
        func backendChildrenQuitWithApp() async throws {
            let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-backend-\(UUID().uuidString)").path
            let pid = try await launchInstance(app: appURL, dataDir: dir, spawnBackend: true)
            var backend: pid_t?
            defer { kill([pid, backend]) }

            let spawned = await waitUntil(timeout: 8) {
                backend = backendPid(of: pid, app: appURL)
                return backend != nil
            }
            #expect(spawned)
            guard spawned, let backend else { return }

            var row: AppInfo?
            _ = await waitUntil(timeout: 8) {
                row = await fixtureRows().first { $0.pids.contains(pid) }
                return row != nil
            }
            guard let row else {
                Issue.record("fixture row missing")
                return
            }

            let results = await QuitService.shared.quit(apps: [row], force: false)
            #expect(results.first?.success == true)
            let allGone = await waitUntil(timeout: 6) {
                !QuitService.processIsRunning(pid) && !QuitService.processIsRunning(backend)
            }
            #expect(allGone, "backend child must not be orphaned")
        }

        @Test("Refused normal quit leaves the app and its backend untouched; force quit removes both")
        func refusedQuitKeepsBackend() async throws {
            let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-refuse-\(UUID().uuidString)").path
            let pid = try await launchInstance(app: appURL, dataDir: dir, refuseQuit: true, spawnBackend: true)
            var backend: pid_t?
            defer { kill([pid, backend]) }

            let spawned = await waitUntil(timeout: 8) {
                backend = backendPid(of: pid, app: appURL)
                return backend != nil
            }
            #expect(spawned)
            guard spawned, let backend else { return }

            var row: AppInfo?
            _ = await waitUntil(timeout: 8) {
                row = await fixtureRows().first { $0.pids.contains(pid) }
                return row != nil
            }
            guard let row else {
                Issue.record("fixture row missing")
                return
            }

            let normal = await QuitService.shared.quit(apps: [row], force: false)
            #expect(normal.first?.success == false)
            #expect(normal.first?.forced == false)
            try? await Task.sleep(for: .seconds(1))
            #expect(QuitService.processIsRunning(pid), "normal quit must never escalate to force")
            #expect(QuitService.processIsRunning(backend), "helpers stay while the app refused to quit")

            let forced = await QuitService.shared.quit(apps: [row], force: true)
            #expect(forced.first?.success == true)
            let allGone = await waitUntil(timeout: 6) {
                !QuitService.processIsRunning(pid) && !QuitService.processIsRunning(backend)
            }
            #expect(allGone)
        }

        @Test(
            "Window control lists, shows and closes a real window",
            .enabled(if: AXIsProcessTrusted())
        )
        func windowControl() async throws {
            let appURL = URL(fileURLWithPath: try #require(instanceFixtureApp))
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-win-\(UUID().uuidString)").path
            let pid = try await launchInstance(app: appURL, dataDir: dir)
            defer { kill([pid]) }

            var windows: [AppWindowControl.Window] = []
            let found = await waitUntil(timeout: 8) {
                windows = AppWindowControl.windows(pid: pid)
                return windows.count == 1
            }
            #expect(found)
            guard found else { return }
            #expect(windows[0].title == "QuitX Last Window Integration Fixture")
            #expect(AppWindowControl.close(windows) == 1)
            let closed = await waitUntil(timeout: 4) { AppWindowControl.windows(pid: pid).isEmpty }
            #expect(closed)
            #expect(QuitService.processIsRunning(pid), "closing windows must not quit the app")
        }
    }
}
