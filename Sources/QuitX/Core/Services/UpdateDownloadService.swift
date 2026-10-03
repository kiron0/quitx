import AppKit
import Foundation

enum UpdateState: Equatable {
    case idle
    case downloading(progress: Double, bytesDownloaded: Int64, totalBytes: Int64, speed: String)
    case extracting
    case ready(stagedURL: URL, version: String)
    case failed(message: String)
}

enum UpdateError: LocalizedError, Equatable {
    case invalidDownloadURL
    case downloadFailed(String)
    case mountFailed
    case copyFailed
    case appNotFoundInDMG
    case invalidBundle
    case destinationNotWritable(String)
    case scriptExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDownloadURL:
            return "Invalid update download URL."
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .mountFailed:
            return "Failed to mount update disk image."
        case .copyFailed:
            return "Failed to extract application from disk image."
        case .appNotFoundInDMG:
            return "QuitX.app not found inside update disk image."
        case .invalidBundle:
            return "Invalid application bundle signature or identifier."
        case .destinationNotWritable(let path):
            return "Cannot write to destination: \(path)"
        case .scriptExecutionFailed(let reason):
            return "Failed to run update script: \(reason)"
        }
    }
}

@MainActor
final class UpdateDownloadService: NSObject, ObservableObject {
    static let shared = UpdateDownloadService()

    @Published private(set) var state: UpdateState = .idle
    @Published private(set) var targetVersion: String = ""
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var bytesDownloaded: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var downloadSpeed: String = ""

    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var lastSpeedTime: Date?
    private var lastSpeedBytes: Int64 = 0
    private(set) var currentDownloadURL: URL?
    private(set) var currentReleaseWebURL: URL?

    override init() {
        super.init()
    }

    func startDownload(from url: URL, version: String, releaseWebURL: URL? = nil) {
        cancelDownload()

        currentDownloadURL = url
        currentReleaseWebURL = releaseWebURL
        targetVersion = version
        downloadProgress = 0.0
        bytesDownloaded = 0
        totalBytes = 0
        downloadSpeed = ""
        lastSpeedTime = nil
        lastSpeedBytes = 0
        state = .downloading(progress: 0.0, bytesDownloaded: 0, totalBytes: 0, speed: "")

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)

        let task = session?.downloadTask(with: url)
        downloadTask = task
        task?.resume()
    }

    func retryLastDownload() {
        guard let url = currentDownloadURL, !targetVersion.isEmpty else { return }
        startDownload(from: url, version: targetVersion, releaseWebURL: currentReleaseWebURL)
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
        downloadProgress = 0.0
        bytesDownloaded = 0
        totalBytes = 0
        downloadSpeed = ""
    }

    func reset() {
        cancelDownload()
        targetVersion = ""
        currentDownloadURL = nil
        currentReleaseWebURL = nil
    }

    // MARK: - DMG Extraction Pipeline

    nonisolated func extractAppFromDMG(dmgURL: URL) async throws -> URL {
        let mountPoint = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXMount-\(UUID().uuidString)")
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXStaged-\(UUID().uuidString)")
        let stagedAppURL = stagingDir.appendingPathComponent("QuitX.app")

        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        // 1. Mount DMG silently without showing in Finder
        let attachProcess = Process()
        attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attachProcess.arguments = [
            "attach",
            dmgURL.path,
            "-mountpoint",
            mountPoint.path,
            "-nobrowse",
            "-readonly",
            "-quiet"
        ]

        try attachProcess.run()
        attachProcess.waitUntilExit()
        guard attachProcess.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: mountPoint)
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.mountFailed
        }

        defer {
            // Detach DMG when finished or on error
            let detachProcess = Process()
            detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detachProcess.arguments = ["detach", mountPoint.path, "-force", "-quiet"]
            try? detachProcess.run()
            detachProcess.waitUntilExit()
            try? FileManager.default.removeItem(at: mountPoint)
            try? FileManager.default.removeItem(at: dmgURL.deletingLastPathComponent())
        }

        // 2. Locate QuitX.app in mount point
        let sourceAppURL: URL
        let defaultAppURL = mountPoint.appendingPathComponent("QuitX.app")
        if FileManager.default.fileExists(atPath: defaultAppURL.path) {
            sourceAppURL = defaultAppURL
        } else {
            let contents = (try? FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? []
            guard let foundApp = contents.first(where: { $0.pathExtension == "app" }) else {
                try? FileManager.default.removeItem(at: stagingDir)
                throw UpdateError.appNotFoundInDMG
            }
            sourceAppURL = foundApp
        }

        // 3. Copy .app to staging directory
        let copyProcess = Process()
        copyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        copyProcess.arguments = [sourceAppURL.path, stagedAppURL.path]
        try copyProcess.run()
        copyProcess.waitUntilExit()
        guard copyProcess.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.copyFailed
        }

        // 4. Verify bundle structure and identifier
        guard let bundle = Bundle(url: stagedAppURL),
              bundle.bundleIdentifier == "io.coreify.quitx" else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.invalidBundle
        }

        guard let executableURL = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.invalidBundle
        }

        return stagedAppURL
    }

    // MARK: - Atomic Replacement & Relaunch

    nonisolated static func resolveDestinationAppURL() -> URL {
        let mainBundle = Bundle.main.bundleURL
        if mainBundle.pathExtension == "app" {
            return mainBundle
        }

        let systemApp = URL(fileURLWithPath: "/Applications/QuitX.app")
        if FileManager.default.fileExists(atPath: systemApp.path) {
            return systemApp
        }

        let userApp = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/QuitX.app")
        if FileManager.default.fileExists(atPath: userApp.path) {
            return userApp
        }

        return systemApp
    }

    nonisolated static func generateRelaunchScript(targetPID: Int32, srcAppPath: String, destAppPath: String) -> String {
        return """
        #!/bin/bash
        TARGET_PID=\(targetPID)
        SRC_APP="\(srcAppPath)"
        DEST_APP="\(destAppPath)"

        # 1. Wait for current running QuitX process to exit (max 5 seconds)
        COUNT=0
        while kill -0 "$TARGET_PID" 2>/dev/null; do
            sleep 0.1
            COUNT=$((COUNT + 1))
            if [ $COUNT -ge 50 ]; then
                kill -9 "$TARGET_PID" 2>/dev/null || true
                break
            fi
        done

        # 2. Atomically swap bundle
        rm -rf "$DEST_APP"
        ditto "$SRC_APP" "$DEST_APP"

        # 3. Clean attributes & staging
        xattr -rd com.apple.quarantine "$DEST_APP" 2>/dev/null || true
        rm -rf "$(dirname "$SRC_APP")"

        # 4. Relaunch QuitX
        open "$DEST_APP"

        # 5. Remove updater script
        rm -- "$0"
        """
    }

    func installAndRelaunch(stagedURL: URL) {
        var destURL = Self.resolveDestinationAppURL()
        let parentDir = destURL.deletingLastPathComponent()

        if !FileManager.default.isWritableFile(atPath: parentDir.path) {
            let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            try? FileManager.default.createDirectory(at: userApps, withIntermediateDirectories: true)
            destURL = userApps.appendingPathComponent("QuitX.app")
        }

        let scriptContent = Self.generateRelaunchScript(
            targetPID: ProcessInfo.processInfo.processIdentifier,
            srcAppPath: stagedURL.path,
            destAppPath: destURL.path
        )

        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quitx_relaunch_\(UUID().uuidString).sh")

        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            try process.run()

            NSApp.terminate(nil)
        } catch {
            state = .failed(message: "Failed to launch updater: \(error.localizedDescription)")
        }
    }

    // MARK: - Progress & Format Helpers

    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    nonisolated static func formatSpeed(bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    fileprivate func handleProgress(bytesWritten: Int64, totalWritten: Int64, expectedToWrite: Int64) {
        bytesDownloaded = totalWritten
        totalBytes = expectedToWrite

        if expectedToWrite > 0 {
            downloadProgress = min(1.0, max(0.0, Double(totalWritten) / Double(expectedToWrite)))
        } else {
            downloadProgress = 0.0
        }

        let now = Date()
        if let lastTime = lastSpeedTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed >= 0.3 {
                let delta = totalWritten - lastSpeedBytes
                if delta >= 0 {
                    let speed = Double(delta) / elapsed
                    downloadSpeed = Self.formatSpeed(bytesPerSecond: speed)
                }
                lastSpeedTime = now
                lastSpeedBytes = totalWritten
            }
        } else {
            lastSpeedTime = now
            lastSpeedBytes = totalWritten
            downloadSpeed = ""
        }

        state = .downloading(
            progress: downloadProgress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            speed: downloadSpeed
        )
    }

    fileprivate func handleDownloadFinished(tempLocation: URL) async {
        let updateDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXUpdate-\(UUID().uuidString)")
        let persistentDMG = updateDir.appendingPathComponent("QuitX.dmg")

        do {
            try FileManager.default.createDirectory(at: updateDir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: tempLocation, to: persistentDMG)

            state = .extracting

            let stagedURL = try await extractAppFromDMG(dmgURL: persistentDMG)
            state = .ready(stagedURL: stagedURL, version: targetVersion)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    fileprivate func handleDownloadFailed(error: Error) {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            state = .idle
            return
        }
        state = .failed(message: error.localizedDescription)
    }
}

// MARK: - URLSessionDownloadDelegate

extension UpdateDownloadService: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            self.handleProgress(
                bytesWritten: bytesWritten,
                totalWritten: totalBytesWritten,
                expectedToWrite: totalBytesExpectedToWrite
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Move file synchronously out of location before delegate returns
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXDownload-\(UUID().uuidString)")
        let savedTempFile = tempDir.appendingPathComponent("QuitX.dmg")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: savedTempFile)

            Task { @MainActor in
                await self.handleDownloadFinished(tempLocation: savedTempFile)
            }
        } catch {
            Task { @MainActor in
                self.state = .failed(message: "Failed to process downloaded file: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.handleDownloadFailed(error: error)
            }
        }
    }
}
