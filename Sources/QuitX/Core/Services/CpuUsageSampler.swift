import Foundation
import Darwin
import os

enum CpuUsageSampler {
    private struct State: Sendable {
        var previous: [pid_t: UInt64] = [:]
        var usages: [pid_t: Double] = [:]
        var selfMachTotal: UInt64 = 0
        var selfCpuMicros: UInt64 = 0
        var factor: Double = CpuUsageSampler.defaultFactor
        var lastSampleTime: TimeInterval = 0
    }

    private static let defaultFactor: Double = 24.0
    private static let calibrationThreshold: UInt64 = 5_000_000
    private static let smoothing: Double = 0.5

    private static let fastInterval: DispatchTimeInterval = .seconds(1)
    private static let idleInterval: DispatchTimeInterval = .seconds(10)
    private static let demandWindow: TimeInterval = 5

    private static let queue = DispatchQueue(label: "quitx.cpu.usage", qos: .utility)
    private static let lock = OSAllocatedUnfairLock(initialState: State())
    private static let timerLock = NSLock()
    nonisolated(unsafe) private static var timer: DispatchSourceTimer?
    nonisolated(unsafe) private static var isFastCadence = false
    nonisolated(unsafe) private static var lastDemand: TimeInterval = 0

    static func start() {
        timerLock.lock()
        defer { timerLock.unlock() }
        guard timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        isFastCadence = ProcessInfo.processInfo.systemUptime - lastDemand <= demandWindow
        source.schedule(
            deadline: .now(),
            repeating: isFastCadence ? fastInterval : idleInterval,
            leeway: isFastCadence ? .milliseconds(250) : .seconds(1)
        )
        source.setEventHandler { tick() }
        timer = source
        source.resume()
    }

    static func stop() {
        timerLock.lock()
        let existing = timer
        timer = nil
        isFastCadence = false
        timerLock.unlock()
        existing?.cancel()
        lock.withLock { state in
            state.previous = [:]
            state.usages = [:]
            state.selfMachTotal = 0
            state.selfCpuMicros = 0
            state.factor = defaultFactor
            state.lastSampleTime = 0
        }
    }

    static func usages() -> [pid_t: Double] {
        noteDemand()
        return lock.withLock { $0.usages }
    }

    private static func noteDemand() {
        timerLock.lock()
        defer { timerLock.unlock() }
        lastDemand = ProcessInfo.processInfo.systemUptime
        guard let timer, !isFastCadence else { return }
        isFastCadence = true
        timer.schedule(deadline: .now(), repeating: fastInterval, leeway: .milliseconds(250))
    }

    private static func relaxCadenceIfIdle(now: TimeInterval) {
        timerLock.lock()
        defer { timerLock.unlock() }
        guard let timer, isFastCadence, now - lastDemand > demandWindow else { return }
        isFastCadence = false
        timer.schedule(deadline: .now() + idleInterval, repeating: idleInterval, leeway: .seconds(1))
    }

    private static func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        defer { relaxCadenceIfIdle(now: now) }
        let totals = readTotals()
        guard !totals.isEmpty else { return }
        let selfPid = ProcessInfo.processInfo.processIdentifier
        let selfMach = totals[selfPid] ?? 0
        let selfCpu = selfCpuMicroseconds()

        lock.withLock { state in
            let elapsed = now - state.lastSampleTime
            guard elapsed > 0.2 else { return }
            state.lastSampleTime = now

            let previous = state.previous
            state.previous = totals

            let factor = resolveFactor(state: &state, selfMach: selfMach, selfCpu: selfCpu)
            guard factor > 0 else { return }

            var result: [pid_t: Double] = [:]
            result.reserveCapacity(totals.count)
            for (pid, total) in totals {
                guard let before = previous[pid], total >= before else { continue }
                let machDelta = total - before
                guard machDelta > 0 else { continue }
                let microseconds = Double(machDelta) / factor
                guard microseconds.isFinite else { continue }
                let percent = microseconds / (elapsed * 1_000_000) * 100
                guard percent.isFinite, percent >= 0 else { continue }
                if let existing = state.usages[pid] {
                    result[pid] = existing * (1 - smoothing) + percent * smoothing
                } else {
                    result[pid] = percent
                }
            }
            state.usages = result
        }
    }

    private static func resolveFactor(
        state: inout State,
        selfMach: UInt64,
        selfCpu: UInt64
    ) -> Double {
        if selfMach > state.selfMachTotal {
            state.selfMachTotal = selfMach
        }
        if selfCpu > state.selfCpuMicros {
            state.selfCpuMicros = selfCpu
        }
        guard state.selfCpuMicros >= calibrationThreshold else { return state.factor }
        let measured = Double(state.selfMachTotal) / Double(state.selfCpuMicros)
        guard measured > 0, measured.isFinite, measured < 10_000 else { return state.factor }
        state.factor = measured
        return state.factor
    }

    private static func readTotals() -> [pid_t: UInt64] {
        var totals: [pid_t: UInt64] = [:]
        let estimated = max(0, Int(proc_listallpids(nil, 0)))
        var buffer = [pid_t](repeating: 0, count: max(1024, estimated + 128))
        let count = proc_listallpids(&buffer, Int32(buffer.count * MemoryLayout<pid_t>.stride))
        guard count > 0 else { return totals }
        totals.reserveCapacity(Int(count))

        for pid in buffer.prefix(Int(count)) where pid > 0 {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { continue }
            totals[pid] = info.pti_total_user &+ info.pti_total_system
        }
        return totals
    }

    private static func selfCpuMicroseconds() -> UInt64 {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        let total = Int64(usage.ru_utime.tv_sec) * 1_000_000
            + Int64(usage.ru_utime.tv_usec)
            + Int64(usage.ru_stime.tv_sec) * 1_000_000
            + Int64(usage.ru_stime.tv_usec)
        return total > 0 ? UInt64(total) : 0
    }
}
