import Testing
import Foundation
import Darwin
@testable import QuitX

@Suite("Port kill integration", .serialized)
struct PortKillIntegrationTests {
    struct Listener {
        let shell: Process
        let port: Int
        let pid: pid_t
        let childPid: pid_t?
        let directory: URL

        func cleanup() {
            if let childPid { _ = Darwin.kill(childPid, SIGKILL) }
            _ = Darwin.kill(pid, SIGKILL)
            if shell.isRunning { shell.terminate() }
            try? FileManager.default.removeItem(at: directory)
        }
    }

    static let script = """
    use IO::Socket::INET;
    my ($port, $ignore, $fork, $dir) = @ARGV;
    if ($ignore) { $SIG{TERM} = 'IGNORE'; $SIG{INT} = 'IGNORE'; }
    my $s = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $port, Listen => 5, ReuseAddr => 1) or exit 3;
    if ($fork) {
        my $c = fork();
        if ($c == 0) { close($s); if ($ignore) { $SIG{TERM} = 'IGNORE'; } sleep 600; exit 0; }
        open(my $cf, '>', "$dir/child") or exit 4; print $cf $c; close($cf);
    }
    open(my $f, '>', "$dir/pid.tmp") or exit 4; print $f $$; close($f); rename("$dir/pid.tmp", "$dir/pid");
    sleep 600;
    """

    static func readPid(_ url: URL) -> pid_t? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        Darwin.kill(pid, 0) == 0
    }

    static func waitUntilDead(_ pid: pid_t, timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var status: Int32 = 0
            _ = waitpid(pid, &status, WNOHANG)
            if !isAlive(pid) { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return !isAlive(pid)
    }

    static func startListener(ignoreSignals: Bool = false, fork: Bool = false) async throws -> Listener {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-port-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let scriptURL = dir.appendingPathComponent("listen.pl")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        for _ in 0..<8 {
            let port = Int.random(in: 41000...48999)
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("pid"))
            let shell = Process()
            shell.executableURL = URL(fileURLWithPath: "/bin/sh")
            shell.arguments = ["-c", "/usr/bin/perl \"$0\" \"$1\" \"$2\" \"$3\" \"$4\"; sleep 30",
                               scriptURL.path, String(port), ignoreSignals ? "1" : "0", fork ? "1" : "0", dir.path]
            shell.standardOutput = FileHandle.nullDevice
            shell.standardError = FileHandle.nullDevice
            try shell.run()

            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                if let pid = readPid(dir.appendingPathComponent("pid")) {
                    let child = fork ? readPid(dir.appendingPathComponent("child")) : nil
                    return Listener(shell: shell, port: port, pid: pid, childPid: child, directory: dir)
                }
                if !shell.isRunning { break }
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            if shell.isRunning { shell.terminate() }
        }
        throw CocoaError(.fileNoSuchFile)
    }

    static func scannedPort(_ listener: Listener) async -> PortInfo? {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let ports = await PortService.shared.fetchListeningPorts()
            if let match = ports.first(where: { $0.port == listener.port && $0.pid == listener.pid }) {
                return match
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return nil
    }

    static func portIsFree(_ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    @Test("Scan finds a real listener with identity and working directory")
    func scanFindsListener() async throws {
        let listener = try await Self.startListener()
        defer { listener.cleanup() }
        let info = try #require(await Self.scannedPort(listener))
        #expect(info.protocolName == "TCP")
        #expect(info.bindAddress.contains("127.0.0.1"))
        #expect(info.processStartTime != nil)
        #expect(info.cwd?.isEmpty == false)
        #expect(!info.isSystemProtected)
        #expect(!Self.portIsFree(listener.port))
    }

    @Test("Terminate, interrupt and force each free the port", arguments: [TerminationMode.terminate, .interrupt, .force])
    func killModesFreePort(mode: TerminationMode) async throws {
        let listener = try await Self.startListener()
        defer { listener.cleanup() }
        let info = try #require(await Self.scannedPort(listener))
        let killed = await PortService.shared.killPort(info, mode: mode)
        #expect(killed)
        #expect(await Self.waitUntilDead(listener.pid))
        #expect(Self.portIsFree(listener.port))
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(await PortService.shared.fetchListeningPorts().contains { $0.port == listener.port } == false)
    }

    @Test("Repeat scans reuse metadata while listeners are unchanged")
    func repeatScanReusesMetadata() async throws {
        let listener = try await Self.startListener()
        defer { listener.cleanup() }
        let first = try #require(await Self.scannedPort(listener))
        var reused = false
        for _ in 0..<6 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let ports = await PortService.shared.fetchListeningPorts()
            let again = ports.first { $0.port == listener.port && $0.pid == listener.pid }
            #expect(again?.processStartTime == first.processStartTime)
            if PortService.shared.lastScanMetrics.metadata == 0 {
                reused = true
                break
            }
        }
        #expect(reused)
    }

    @Test("Process ignoring SIGTERM and SIGINT is escalated to SIGKILL", arguments: [TerminationMode.terminate, .interrupt])
    func escalatesStubbornProcess(mode: TerminationMode) async throws {
        let listener = try await Self.startListener(ignoreSignals: true)
        defer { listener.cleanup() }
        let info = try #require(await Self.scannedPort(listener))
        let killed = await PortService.shared.killPort(info, mode: mode)
        #expect(killed)
        #expect(await Self.waitUntilDead(listener.pid))
        #expect(Self.portIsFree(listener.port))
    }

    @Test("Killing a port also stops the listener's child processes but not its shell host")
    func killsProcessTree() async throws {
        let listener = try await Self.startListener(ignoreSignals: true, fork: true)
        defer { listener.cleanup() }
        let child = try #require(listener.childPid)
        let info = try #require(await Self.scannedPort(listener))
        #expect(await PortService.shared.killPort(info, mode: .terminate))
        #expect(await Self.waitUntilDead(listener.pid))
        #expect(await Self.waitUntilDead(child))
        #expect(Self.portIsFree(listener.port))
        #expect(listener.shell.isRunning)
    }

    @Test("Stale port info with a different process identity is refused")
    func refusesStaleIdentity() async throws {
        let listener = try await Self.startListener()
        defer { listener.cleanup() }
        let info = try #require(await Self.scannedPort(listener))
        let stale = PortInfo(
            port: info.port,
            pid: info.pid,
            processName: info.processName,
            protocolName: info.protocolName,
            bindAddress: info.bindAddress,
            executablePath: info.executablePath,
            processStartTime: (info.processStartTime ?? 1) &+ 999_999
        )
        #expect(await PortService.shared.killPort(stale, mode: .force) == false)
        #expect(Self.isAlive(listener.pid))
        #expect(!Self.portIsFree(listener.port))
    }

    @Test("Protected and own processes are never killed")
    func refusesProtected() async throws {
        let own = PortInfo(port: 1, pid: ProcessInfo.processInfo.processIdentifier, processName: "QuitX")
        #expect(await PortService.shared.killPort(own, mode: .force) == false)
        let launchd = PortInfo(port: 1, pid: 1, processName: "launchd")
        #expect(await PortService.shared.killPort(launchd, mode: .force) == false)
        #expect(await PortService.shared.terminateProcessTree(pid: 1, force: true) == false)
        #expect(Self.isAlive(ProcessInfo.processInfo.processIdentifier))
    }
}
