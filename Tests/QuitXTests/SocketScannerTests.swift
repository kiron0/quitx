import Darwin
import Foundation
import Testing
@testable import QuitX

private final class TestListener {
    let descriptor: Int32
    let port: Int

    init?(type: Int32, address: String = "127.0.0.1") {
        let fd = socket(AF_INET, type, type == SOCK_STREAM ? IPPROTO_TCP : IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        inet_pton(AF_INET, address, &addr.sin_addr)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, type != SOCK_STREAM || listen(fd, 1) == 0 else {
            close(fd)
            return nil
        }
        var actual = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actual) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        descriptor = fd
        port = Int(UInt16(bigEndian: actual.sin_port))
    }

    deinit { close(descriptor) }
}

@Suite("Kernel socket scanner")
struct SocketScannerTests {
    @Test("Finds this process's TCP listener with its port and address")
    func findsTCPListener() throws {
        let listener = try #require(TestListener(type: SOCK_STREAM))
        let found = try #require(SocketScanner.listeners(includeUDP: false))
        let mine = found.filter { $0.pid == getpid() && $0.port == listener.port }
        #expect(mine.count == 1)
        #expect(mine.first?.proto == "TCP")
        #expect(mine.first?.address == "127.0.0.1")
        #expect(mine.first?.state == "LISTEN")
        #expect(mine.first?.user.isEmpty == false)
    }

    @Test("UDP sockets only appear when UDP is included")
    func udpOptIn() throws {
        let listener = try #require(TestListener(type: SOCK_DGRAM))
        let tcpOnly = try #require(SocketScanner.listeners(includeUDP: false))
        #expect(!tcpOnly.contains { $0.pid == getpid() && $0.port == listener.port })
        let withUDP = try #require(SocketScanner.listeners(includeUDP: true))
        #expect(withUDP.contains { $0.pid == getpid() && $0.port == listener.port && $0.proto == "UDP" })
    }

    @Test("Network order ports convert like ntohs")
    func portConversion() {
        #expect(SocketScanner.port(fromNetworkOrder: Int32(UInt16(3000).bigEndian)) == 3000)
        #expect(SocketScanner.port(fromNetworkOrder: Int32(UInt16(65535).bigEndian)) == 65535)
    }

    @Test("Working directory comes from the kernel")
    func currentDirectory() {
        #expect(SocketScanner.currentDirectory(pid: getpid()) == FileManager.default.currentDirectoryPath)
    }

    @Test("Kernel scan agrees with lsof and stays fast")
    func agreesWithLsof() async throws {
        let listener = try #require(TestListener(type: SOCK_STREAM))
        let started = Date()
        let kernel = try #require(SocketScanner.listeners(includeUDP: false))
        let kernelSeconds = Date().timeIntervalSince(started)
        let lsofStarted = Date()
        let output = await ProcessRunner.run(executable: "/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcLfntTP"], timeout: 15)
        let lsofSeconds = Date().timeIntervalSince(lsofStarted)
        let fromLsof = PortService.shared.parseLsofOutput(output?.text ?? "")
        let after = SocketScanner.listeners(includeUDP: false) ?? []
        let kernelKeys = Set((kernel + after).map { "\($0.pid):\($0.port)" })
        let lsofKeys = Set(fromLsof.map { "\($0.pid):\($0.port)" })
        #expect(kernelKeys.contains("\(getpid()):\(listener.port)"))
        let missing = fromLsof.filter { lsofKeys.subtracting(kernelKeys).contains("\($0.pid):\($0.port)") }
        let confirmation = await ProcessRunner.run(executable: "/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcLfntTP"], timeout: 15)
        let stillOpen = Set(PortService.shared.parseLsofOutput(confirmation?.text ?? "").map { "\($0.pid):\($0.port)" })
        let latest = Set((SocketScanner.listeners(includeUDP: false) ?? []).map { "\($0.pid):\($0.port)" })
        let stillListening = missing.filter { stillOpen.contains("\($0.pid):\($0.port)") && !latest.contains("\($0.pid):\($0.port)") }
        #expect(stillListening.isEmpty, "kernel scan missed \(missing.map { "\($0.process) pid \($0.pid) :\($0.port)" })")
        #expect(kernelSeconds < 1)
        let qa = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".qa")
        if FileManager.default.fileExists(atPath: qa.path) {
            let report = String(format: "kernel scan %.3fs (%d listeners), lsof %.3fs (%d listeners)\n", kernelSeconds, kernel.count, lsofSeconds, fromLsof.count)
            try? report.write(to: qa.appendingPathComponent("perf.txt"), atomically: true, encoding: .utf8)
        }
    }
}
