import AppKit
import Foundation
import Darwin

@MainActor
final class SingleInstanceService {
    static let shared = SingleInstanceService()

    private var launchObserver: NSObjectProtocol?

    private init() {}

    func prepareForLaunch() async -> Bool {
        let current = NSRunningApplication.current
        let candidates = matchingApplications()
        guard candidates.count > 1 else { return true }

        let winner = candidates.reduce(current) { preferred($1, over: $0) ? $1 : $0 }
        guard winner.processIdentifier == current.processIdentifier else {
            notifyAndActivate(winner)
            return false
        }

        await terminate(candidates.filter { $0.processIdentifier != current.processIdentifier })
        return true
    }

    func startMonitoring() {
        guard launchObserver == nil else { return }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                await self?.handleNewInstance(application)
            }
        }
    }

    func stopMonitoring() {
        guard let launchObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        self.launchObserver = nil
    }

    private func handleNewInstance(_ application: NSRunningApplication) async {
        let current = NSRunningApplication.current
        guard Self.isRunning(application),
              application.processIdentifier != current.processIdentifier,
              Self.isQuitX(application) else { return }

        if preferred(application, over: current) {
            notifyAndActivate(application)
            NSApp.terminate(nil)
        } else {
            await terminate([application])
        }
    }

    private func matchingApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { Self.isRunning($0) && Self.isQuitX($0) }
    }

    private static func isQuitX(_ application: NSRunningApplication) -> Bool {
        if application.processIdentifier == ProcessInfo.processInfo.processIdentifier { return true }
        guard isRunning(application) else { return false }
        guard let bundleIdentifier = application.bundleIdentifier else { return false }
        return QuitXConstants.supportedBundleIdentifiers.contains(bundleIdentifier)
    }

    private static func isRunning(_ application: NSRunningApplication) -> Bool {
        !application.isTerminated && QuitService.processIsRunning(application.processIdentifier)
    }

    private func preferred(_ lhs: NSRunningApplication, over rhs: NSRunningApplication) -> Bool {
        Self.isPreferred(
            version: version(of: lhs),
            pid: lhs.processIdentifier,
            over: version(of: rhs),
            pid: rhs.processIdentifier
        )
    }

    static func isPreferred(version lhsVersion: String, pid lhsPid: pid_t, over rhsVersion: String, pid rhsPid: pid_t) -> Bool {
        let comparison = compareVersions(lhsVersion, rhsVersion)
        if comparison != 0 { return comparison > 0 }
        return lhsPid < rhsPid
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        VersionComparator.compare(lhs, rhs)
    }

    private func version(of application: NSRunningApplication) -> String {
        guard let bundleURL = application.bundleURL,
              let bundle = Bundle(url: bundleURL) else { return "0" }
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private func terminate(_ applications: [NSRunningApplication]) async {
        guard !applications.isEmpty else { return }

        for application in applications where Self.isRunning(application) {
            _ = application.terminate()
        }

        await waitForTermination(applications, timeout: 3)

        let remaining = applications.filter(Self.isRunning)
        for application in remaining {
            _ = application.forceTerminate()
            let pid = application.processIdentifier
            if QuitService.processIsRunning(pid) {
                Darwin.kill(pid, SIGKILL)
            }
        }

        await waitForTermination(remaining, timeout: 2)

        for application in remaining where Self.isRunning(application) {
            NSLog("Could not terminate older QuitX instance with PID %d", application.processIdentifier)
        }
    }

    private func waitForTermination(_ applications: [NSRunningApplication], timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while applications.contains(where: Self.isRunning), Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func notifyAndActivate(_ application: NSRunningApplication) {
        DistributedNotificationCenter.default().postNotificationName(
            QuitXConstants.Notifications.showPopover,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        if #available(macOS 14.0, *) {
            application.activate()
        } else {
            application.activate(options: [])
        }
    }
}
