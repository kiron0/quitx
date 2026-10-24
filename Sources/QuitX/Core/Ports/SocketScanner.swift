import Darwin
import Foundation

enum SocketScanner {
    static func listeners(includeUDP: Bool) -> [PortService.RawParsedLsof]? {
        guard let pids = allPids() else { return nil }
        var results: [PortService.RawParsedLsof] = []
        var userNames: [uid_t: String] = [:]
        for pid in pids where pid > 0 {
            let sockets = listeningSockets(pid: pid, includeUDP: includeUDP)
            guard !sockets.isEmpty else { continue }
            let info = bsdInfo(pid: pid)
            let name = info.map { processName(from: $0) } ?? "unknown"
            var user = ""
            if let uid = info?.pbi_uid {
                if let cached = userNames[uid] {
                    user = cached
                } else {
                    let resolved = userName(uid: uid)
                    userNames[uid] = resolved
                    user = resolved
                }
            }
            for socket in sockets {
                var entry = PortService.RawParsedLsof()
                entry.pid = pid
                entry.port = socket.port
                entry.process = name
                entry.user = user
                entry.proto = socket.proto
                entry.state = "LISTEN"
                entry.address = socket.address
                results.append(entry)
            }
        }
        return results
    }

    struct Socket: Equatable {
        let port: Int
        let proto: String
        let address: String
    }

    static func allPids() -> [pid_t]? {
        let estimated = proc_listallpids(nil, 0)
        guard estimated > 0 else { return nil }
        var pids = [pid_t](repeating: 0, count: Int(estimated) + 64)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return nil }
        return Array(pids.prefix(Int(count)))
    }

    static func listeningSockets(pid: pid_t, includeUDP: Bool) -> [Socket] {
        let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufferSize > 0 else { return [] }
        let fdInfoSize = MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bufferSize) / fdInfoSize + 8)
        let used = fds.withUnsafeMutableBytes { buffer in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer.baseAddress, Int32(buffer.count))
        }
        guard used > 0 else { return [] }
        let fdCount = Int(used) / fdInfoSize
        var sockets: [Socket] = []
        for fd in fds.prefix(fdCount) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var info = socket_fdinfo()
            let infoSize = Int32(MemoryLayout<socket_fdinfo>.stride)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, infoSize) == infoSize else { continue }
            let kind = Int(info.psi.soi_kind)
            if kind == Int(SOCKINFO_TCP) {
                let tcp = info.psi.soi_proto.pri_tcp
                guard Int(tcp.tcpsi_state) == Int(TSI_S_LISTEN) else { continue }
                if let socket = makeSocket(tcp.tcpsi_ini, proto: "TCP") { sockets.append(socket) }
            } else if includeUDP, kind == Int(SOCKINFO_IN), Int(info.psi.soi_protocol) == Int(IPPROTO_UDP) {
                if let socket = makeSocket(info.psi.soi_proto.pri_in, proto: "UDP") { sockets.append(socket) }
            }
        }
        return sockets
    }

    static func port(fromNetworkOrder value: Int32) -> Int {
        Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: value)))
    }

    private static func makeSocket(_ ini: in_sockinfo, proto: String) -> Socket? {
        let port = port(fromNetworkOrder: ini.insi_lport)
        guard port > 0 else { return nil }
        return Socket(port: port, proto: proto, address: address(ini))
    }

    private static func address(_ ini: in_sockinfo) -> String {
        let flags = Int32(ini.insi_vflag)
        if flags & Int32(INI_IPV6) != 0 {
            var addr = ini.insi_laddr.ina_6
            if isZero(&addr) { return "*" }
            return format(family: AF_INET6, &addr, length: Int(INET6_ADDRSTRLEN))
        }
        var addr = ini.insi_laddr.ina_46.i46a_addr4
        if addr.s_addr == 0 { return "*" }
        return format(family: AF_INET, &addr, length: Int(INET_ADDRSTRLEN))
    }

    private static func isZero<T>(_ value: inout T) -> Bool {
        withUnsafeBytes(of: &value) { bytes in bytes.allSatisfy { $0 == 0 } }
    }

    private static func format<T>(family: Int32, _ value: inout T, length: Int) -> String {
        var buffer = [CChar](repeating: 0, count: length + 1)
        let result = withUnsafePointer(to: &value) { pointer in
            inet_ntop(family, pointer, &buffer, socklen_t(buffer.count))
        }
        guard result != nil else { return "*" }
        return String(cString: buffer)
    }

    private static func bsdInfo(pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    private static func processName(from info: proc_bsdinfo) -> String {
        var info = info
        let name = withUnsafeBytes(of: &info.pbi_name) { bytes -> String in
            let chars = bytes.bindMemory(to: CChar.self)
            guard let base = chars.baseAddress else { return "" }
            return String(cString: base)
        }
        if !name.isEmpty { return name }
        return withUnsafeBytes(of: &info.pbi_comm) { bytes -> String in
            let chars = bytes.bindMemory(to: CChar.self)
            guard let base = chars.baseAddress else { return "unknown" }
            return String(cString: base)
        }
    }

    private static func userName(uid: uid_t) -> String {
        guard let entry = getpwuid(uid), let name = entry.pointee.pw_name else { return String(uid) }
        return String(cString: name)
    }

    static func parentPid(of pid: pid_t) -> pid_t? {
        guard let info = bsdInfo(pid: pid) else { return nil }
        let parent = pid_t(info.pbi_ppid)
        return parent > 0 ? parent : nil
    }

    static func withAncestors(_ pids: [pid_t], maxDepth: Int = 32) -> [pid_t] {
        var result = Set(pids)
        for pid in pids {
            var current = pid
            var depth = 0
            while depth < maxDepth, let parent = parentPid(of: current), parent > 1, result.insert(parent).inserted {
                current = parent
                depth += 1
            }
        }
        return result.sorted()
    }

    static func currentDirectory(pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { bytes -> String in
            let chars = bytes.bindMemory(to: CChar.self)
            guard let base = chars.baseAddress else { return "" }
            return String(cString: base)
        }
        return path.isEmpty ? nil : path
    }
}
