import Foundation
import Testing
@testable import QuitX

@Suite("Quit mode consistency")
struct QuitModeConsistencyTests {
    @Test("Every automatic quit path follows the Quit mode setting")
    func automaticPathsUseSetting() throws {
        var config = QuitXConfig.default
        config.force = .force
        #expect(config.prefersForceQuit)
        config.force = .normal
        #expect(!config.prefersForceQuit)

        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/QuitX")
        let automatic = [
            "Core/Services/AutoQuitService.swift",
            "Core/Services/QuitTimerService.swift",
            "Core/Services/SleepService.swift",
            "UI/MenuBar/RescueConsentPanel.swift",
            "Core/Services/LastWindowQuitService.swift"
        ]
        for path in automatic {
            let text = try String(contentsOf: sources.appendingPathComponent(path), encoding: .utf8)
            #expect(!text.contains("force: false)"), "\(path) hard-codes a normal quit")
            #expect(!text.contains("force: true)"), "\(path) hard-codes a force quit")
            #expect(text.contains("prefersForceQuit"), "\(path) ignores the Quit mode setting")
        }
    }

    @Test("Auto Quit does not count time asleep as inactivity")
    func sleepNotInactive() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let timestamps: [pid_t: Date] = [
            10: base.addingTimeInterval(-600),
            11: base.addingTimeInterval(-60)
        ]
        let slept = base
        let woke = base.addingTimeInterval(8 * 3600)
        let shifted = AutoQuitService.excludingSleep(timestamps, sleptAt: slept, wokeAt: woke)
        #expect(shifted[10] == woke.addingTimeInterval(-600))
        #expect(shifted[11] == woke.addingTimeInterval(-60))
        #expect(AutoQuitService.excludingSleep(timestamps, sleptAt: woke, wokeAt: slept) == timestamps)
        let future: [pid_t: Date] = [12: woke]
        #expect(AutoQuitService.excludingSleep(future, sleptAt: slept, wokeAt: woke)[12] == woke)
    }
}
