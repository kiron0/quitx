import Foundation
import Testing
@testable import QuitX

@Suite("Quit after sleep", .serialized)
@MainActor
struct SleepQuitTests {
    private static func app(_ name: String, pid: pid_t, background: Bool = false) -> AppInfo {
        AppInfo(name: name, bundleId: "com.example.\(name.lowercased())", pid: pid, pids: [pid], isBackground: background, memoryBytes: 1, cpuUsage: 0)
    }

    private static func date(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let day = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        return calendar.date(byAdding: .minute, value: hour * 60 + minute, to: day) ?? day
    }

    private func withConfig(_ change: (inout QuitXConfig) -> Void, _ body: () async -> Void) async {
        let store = ConfigStore.shared
        let saved = store.config
        var config = saved
        config.quitOnSleep = true
        config.sleepLockStartMinutes = 0
        config.sleepLockEndMinutes = 360
        config.exclude = []
        config.perAppQuitRules = [:]
        config.neverQuitMusic = false
        change(&config)
        store.config = config
        await body()
        store.config = saved
    }

    private func makeService(calls: QuitCalls) -> SleepService {
        let service = SleepService()
        service.appSource = { [Self.app("Slack", pid: 101), Self.app("Agent", pid: 102, background: true)] }
        service.quitter = { apps, force in await calls.record(apps, force) }
        return service
    }

    @Test("Sleeping only records the time and quits nothing")
    func sleepQuitsNothing() async {
        await withConfig({ _ in }) {
            let calls = QuitCalls()
            let service = makeService(calls: calls)
            service.handleSleep(now: Self.date(hour: 1))
            #expect(service.sleepStartDate == Self.date(hour: 1))
            #expect(await calls.calls.isEmpty)
        }
    }

    @Test("Waking after a sleep that touched the range quits with the configured mode")
    func wakeQuitsInRange() async {
        await withConfig({ $0.force = .force }) {
            let calls = QuitCalls()
            let service = makeService(calls: calls)
            service.handleSleep(now: Self.date(hour: 23, dayOffset: -1))
            await service.handleWake(wakeDate: Self.date(hour: 7))
            let recorded = await calls.calls
            #expect(recorded.count == 1)
            #expect(recorded.first?.force == true)
            #expect(recorded.first?.names == ["Slack"])
            #expect(service.sleepStartDate == nil)
        }
        await withConfig({ $0.force = .normal }) {
            let calls = QuitCalls()
            let service = makeService(calls: calls)
            service.handleSleep(now: Self.date(hour: 2))
            await service.handleWake(wakeDate: Self.date(hour: 3))
            #expect(await calls.calls.first?.force == false)
        }
    }

    @Test("Waking after a sleep outside the range leaves apps running")
    func wakeOutsideRange() async {
        await withConfig({ _ in }) {
            let calls = QuitCalls()
            let service = makeService(calls: calls)
            service.handleSleep(now: Self.date(hour: 13))
            await service.handleWake(wakeDate: Self.date(hour: 15))
            #expect(await calls.calls.isEmpty)
            await service.handleWake(wakeDate: Self.date(hour: 16))
            #expect(await calls.calls.isEmpty)
        }
    }

    @Test("Nothing happens on wake when quitting after sleep is off")
    func disabled() async {
        await withConfig({ $0.quitOnSleep = false }) {
            let calls = QuitCalls()
            let service = makeService(calls: calls)
            service.handleSleep(now: Self.date(hour: 1))
            #expect(service.sleepStartDate == nil)
            await service.handleWake(wakeDate: Self.date(hour: 2))
            #expect(await calls.calls.isEmpty)
        }
    }

    @Test("Wake decision and quit mode mapping")
    func decisions() {
        var config = QuitXConfig.default
        config.quitOnSleep = true
        config.sleepLockStartMinutes = 0
        config.sleepLockEndMinutes = 360
        #expect(SleepService.shouldQuitOnWake(sleepStart: Self.date(hour: 5), wakeDate: Self.date(hour: 9), config: config))
        #expect(!SleepService.shouldQuitOnWake(sleepStart: Self.date(hour: 7), wakeDate: Self.date(hour: 9), config: config))
        #expect(!SleepService.shouldQuitOnWake(sleepStart: nil, wakeDate: Self.date(hour: 2), config: config))
        config.force = .force
        #expect(SleepService.forceMode(config))
        config.force = .normal
        #expect(!SleepService.forceMode(config))
    }
}

actor QuitCalls {
    private(set) var calls: [(names: [String], force: Bool)] = []

    func record(_ apps: [AppInfo], _ force: Bool) {
        calls.append((apps.map(\.name), force))
    }
}
