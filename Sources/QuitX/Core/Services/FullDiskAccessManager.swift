import AppKit
import Foundation

@MainActor
final class FullDiskAccessManager: ObservableObject {
    static let shared = FullDiskAccessManager()

    @Published private(set) var hasFullDiskAccess: Bool = false

    private var pollTimer: Timer?
    private var activeObserver: NSObjectProtocol?

    private init() {
        hasFullDiskAccess = Self.checkFullDiskAccess()
        startObserving()
    }

    /// Check if Full Disk Access is granted by attempting a real read of a TCC-protected file.
    /// Uses FileHandle/Data and contentsOfDirectory rather than fileExists/isReadableFile,
    /// because metadata lookups short-circuit before macOS TCC evaluates the request.
    nonisolated static func checkFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let probes = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Safari/CloudTabs.db",
            "\(home)/Library/Safari/Bookmarks.plist",
            "\(home)/Library/Mail",
        ]

        for path in probes {
            if canActuallyRead(path: path) { return true }
        }
        return false
    }

    nonisolated private static func canActuallyRead(path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            return false
        }
        if isDir.boolValue {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: path)
                return true
            } catch {
                return false
            }
        } else {
            guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
                return false
            }
            defer { try? handle.close() }
            return (try? handle.read(upToCount: 1)) != nil
        }
    }

    /// Touches TCC-gated paths on launch so macOS registers QuitX in the Privacy & Security > Full Disk Access list.
    nonisolated func triggerRegistration() {
        Task.detached(priority: .utility) {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let probePaths = [
                "/Library/Application Support/com.apple.TCC/TCC.db",
                "\(home)/Library/Mail",
                "\(home)/Library/Safari/CloudTabs.db",
                "\(home)/Library/Safari/Bookmarks.plist",
                "\(home)/Library/Cookies",
                "\(home)/Library/HTTPStorages",
                "\(home)/Library/Application Support/com.apple.TCC",
            ]
            for path in probePaths {
                _ = Self.canActuallyRead(path: path)
            }
        }
    }

    func startObserving() {
        refresh()
        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }
    }

    func stopObserving() {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
        activeObserver = nil
        stopPolling()
    }

    @discardableResult
    func refresh() -> Bool {
        let granted = Self.checkFullDiskAccess()
        if hasFullDiskAccess != granted {
            hasFullDiskAccess = granted
        }
        return granted
    }

    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let granted = self.refresh()
                if granted {
                    self.stopPolling()
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Opens System Settings directly to Privacy & Security -> Full Disk Access pane.
    func openFullDiskAccessSettings() {
        startPolling()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reveals QuitX.app in Finder so user can easily drag the bundle into System Settings if not auto-listed.
    func revealAppInFinder() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }

    /// Opens System Settings and reveals QuitX in Finder side-by-side.
    func openSettingsAndReveal() {
        openFullDiskAccessSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.revealAppInFinder()
        }
    }
}
