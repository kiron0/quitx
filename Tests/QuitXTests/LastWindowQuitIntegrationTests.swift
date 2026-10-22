import Darwin
import Foundation
import Testing
@testable import QuitX

private let lastWindowFixturePath = ProcessInfo.processInfo.environment["QUITX_LAST_WINDOW_FIXTURE"]

extension GUIIntegrationTests {
    @Suite(
        "Last Window Quit Integration Tests",
        .enabled(if: lastWindowFixturePath != nil)
    )
    @MainActor
    struct LastWindowQuitIntegrationTests {
        @Test("Closing a real last window force-quits its fixture app")
        func testRealLastWindowClose() async throws {
            let fixturePath = try #require(lastWindowFixturePath)
            let stateURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("QuitXLastWindowState-\(UUID().uuidString)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: fixturePath)
            process.environment = ProcessInfo.processInfo.environment.merging([
                "QUITX_FIXTURE_STATE_FILE": stateURL.path
            ]) { _, new in new }
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()

            let pid = process.processIdentifier
            let originalConfig = ConfigStore.shared.config
            let service = LastWindowQuitService(
                restrictedToPID: pid,
                recordsRecentlyQuit: false,
                requiresAccessibilityTrust: false,
                windowCount: { requestedPID in
                    guard requestedPID == pid,
                          let state = try? String(contentsOf: stateURL, encoding: .utf8) else {
                        return nil
                    }
                    return state == "closed" ? 0 : 1
                }
            )

            defer {
                service.stop()
                ConfigStore.shared.config = originalConfig
                if QuitService.processIsRunning(pid) {
                    Darwin.kill(pid, SIGKILL)
                }
                process.waitUntilExit()
                try? FileManager.default.removeItem(at: stateURL)
            }

            let windowAppeared = await waitUntil(timeout: 8) {
                !(LastWindowQuitWindowCounter.visibleWindowIDs()?[pid] ?? []).isEmpty
            }
            #expect(windowAppeared)
            guard windowAppeared else { return }

            var config = originalConfig
            config.quitWhenLastWindowClosed = true
            config.exclude = []
            config.neverQuitMusic = false
            config.perAppQuitRules = [:]
            ConfigStore.shared.config = config
            service.start()

            let beganTracking = await waitUntil(timeout: 4) {
                service.isTracking(pid)
            }
            #expect(beganTracking)
            guard beganTracking else { return }

            #expect(Darwin.kill(pid, SIGUSR2) == 0)
            let minimized = await waitUntil(timeout: 4) {
                (LastWindowQuitWindowCounter.visibleWindowIDs()?[pid] ?? []).isEmpty
            }
            #expect(minimized)
            try? await Task.sleep(for: .seconds(3))
            #expect(QuitService.processIsRunning(pid))

            #expect(Darwin.kill(pid, SIGUSR2) == 0)
            let restored = await waitUntil(timeout: 4) {
                !(LastWindowQuitWindowCounter.visibleWindowIDs()?[pid] ?? []).isEmpty
            }
            #expect(restored)
            guard restored else { return }

            #expect(Darwin.kill(pid, SIGUSR1) == 0)

            let wasForceQuit = await waitUntil(timeout: 10) {
                !QuitService.processIsRunning(pid)
            }
            #expect(wasForceQuit)
        }

        private func waitUntil(
            timeout: TimeInterval,
            condition: @MainActor () -> Bool
        ) async -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if condition() { return true }
                try? await Task.sleep(for: .milliseconds(100))
            }
            return condition()
        }

    }
}
