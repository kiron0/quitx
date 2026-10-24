import Foundation
import Darwin

enum ProcessRunner {
    struct Output {
        let data: Data
        let status: Int32
        let timedOut: Bool

        var text: String { String(decoding: data, as: UTF8.self) }
    }

    static func runSync(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        mergeStandardError: Bool = false,
        environment: [String: String]? = nil
    ) -> Output? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = mergeStandardError ? pipe : FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let timeoutFlag = TimeoutFlag()
        let pid = process.processIdentifier
        let watchdog = DispatchWorkItem {
            guard process.isRunning else { return }
            timeoutFlag.set()
            process.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                if process.isRunning {
                    _ = Darwin.kill(pid, SIGKILL)
                }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
        return Output(data: data, status: process.terminationStatus, timedOut: timeoutFlag.value)
    }

    static func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        mergeStandardError: Bool = false,
        environment: [String: String]? = nil,
        qos: DispatchQoS.QoSClass = .userInitiated
    ) async -> Output? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: qos).async {
                continuation.resume(returning: runSync(
                    executable: executable,
                    arguments: arguments,
                    timeout: timeout,
                    mergeStandardError: mergeStandardError,
                    environment: environment
                ))
            }
        }
    }

    static let cLocaleEnvironment: [String: String] = ["LC_ALL": "C", "LANG": "C"]
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    func set() {
        lock.lock()
        flag = true
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }
}
