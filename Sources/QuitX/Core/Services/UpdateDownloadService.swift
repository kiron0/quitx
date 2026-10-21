import AppKit
import Foundation
import CryptoKit
import Security

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
    case invalidChecksum
    case invalidSignature
    case missingDigest
    case missingSignature
    case versionMismatch
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
        case .invalidChecksum:
            return "Update download checksum does not match the expected value."
        case .invalidSignature:
            return "Update application code signature is missing or invalid."
        case .missingDigest:
            return "Update metadata is missing its checksum digest."
        case .missingSignature:
            return "Update metadata is missing its publisher signature."
        case .versionMismatch:
            return "Update application version does not match the expected version."
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
    private var lastPublishedProgress: Double = -1
    private var stagedDirURL: URL?
    private(set) var currentDownloadURL: URL?
    private(set) var currentDigest: String?
    private(set) var currentEdSignature: String?

    override init() {
        super.init()
    }

    func startDownload(from url: URL, version: String, digest: String? = nil, edSignature: String? = nil) {
        cancelDownload()

        currentDownloadURL = url
        currentDigest = digest
        currentEdSignature = edSignature
        targetVersion = version
        downloadProgress = 0.0
        bytesDownloaded = 0
        totalBytes = 0
        downloadSpeed = ""
        lastSpeedTime = nil
        lastSpeedBytes = 0
        lastPublishedProgress = -1
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
        startDownload(
            from: url,
            version: targetVersion,
            digest: currentDigest,
            edSignature: currentEdSignature
        )
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        session?.invalidateAndCancel()
        session = nil
        clearStagedDirectory()
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
        currentDigest = nil
        currentEdSignature = nil
    }

    private func isActive(session: URLSession, task: URLSessionTask) -> Bool {
        self.session === session && self.downloadTask === task
    }

    private func finishSession(_ completedSession: URLSession, task: URLSessionTask) {
        guard isActive(session: completedSession, task: task) else { return }
        completedSession.finishTasksAndInvalidate()
        session = nil
        downloadTask = nil
    }

    private func clearStagedDirectory() {
        if let stagedDirURL {
            try? FileManager.default.removeItem(at: stagedDirURL)
            self.stagedDirURL = nil
        }
    }

    nonisolated func extractAppFromDMG(dmgURL: URL) async throws -> URL {
        let mountPoint = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXMount-\(UUID().uuidString)")
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXStaged-\(UUID().uuidString)")
        let stagedAppURL = stagingDir.appendingPathComponent("QuitX.app")

        var isMounted = false
        defer {
            if isMounted {
                let detachProcess = Process()
                detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProcess.arguments = ["detach", mountPoint.path, "-force", "-quiet"]
                try? detachProcess.run()
                detachProcess.waitUntilExit()
            }
            try? FileManager.default.removeItem(at: mountPoint)
            try? FileManager.default.removeItem(at: dmgURL.deletingLastPathComponent())
        }

        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

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
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.mountFailed
        }
        isMounted = true

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

        let copyProcess = Process()
        copyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        copyProcess.arguments = [sourceAppURL.path, stagedAppURL.path]
        try copyProcess.run()
        copyProcess.waitUntilExit()
        guard copyProcess.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.copyFailed
        }

        guard let bundle = Bundle(url: stagedAppURL),
              let bundleId = bundle.bundleIdentifier,
              QuitXConstants.supportedBundleIdentifiers.contains(bundleId) else {
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

    nonisolated static func sha256(of url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }

        var hasher = SHA256()

        while let data = try file.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    nonisolated static func normalizedDigest(_ digest: String) -> String {
        digest
            .replacingOccurrences(of: "sha256:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    nonisolated static func verifyDigest(of url: URL, expectedDigest: String) throws {
        let expected = normalizedDigest(expectedDigest)
        guard !expected.isEmpty else { return }
        let actual = try sha256(of: url)
        guard actual == expected else {
            throw UpdateError.invalidChecksum
        }
    }

    nonisolated static func verifyEdSignature(
        of url: URL,
        signatureBase64: String,
        publicKeyBase64: String = QuitXConstants.compiledEdPublicKey
    ) throws {
        guard let signature = Data(base64Encoded: signatureBase64),
              let publicKeyRaw = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRaw)
        else {
            throw UpdateError.invalidSignature
        }

        let payload = try Data(contentsOf: url)
        guard publicKey.isValidSignature(signature, for: payload) else {
            throw UpdateError.invalidSignature
        }
    }

    nonisolated static func currentTeamIdentifier() -> String? {
        let bundleURL = Bundle.main.bundleURL
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &code) == errSecSuccess,
              let code
        else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any]
        else { return nil }

        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }

    nonisolated static func validateSignature(of appURL: URL, expectedTeamIdentifier: String?) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &code) == errSecSuccess,
              let code
        else {
            throw UpdateError.invalidSignature
        }

        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode
        )

        let unsignedStatus = SecStaticCodeCheckValidity(code, flags, nil)
        guard unsignedStatus == errSecSuccess else {
            throw UpdateError.invalidSignature
        }

        guard let expectedTeamIdentifier, !expectedTeamIdentifier.isEmpty else { return }

        guard let bundleId = Bundle(url: appURL)?.bundleIdentifier else {
            throw UpdateError.invalidSignature
        }

        let requirementText = """
        anchor apple generic and
        identifier "\(bundleId)" and
        certificate leaf[subject.OU] = "\(expectedTeamIdentifier)"
        """

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
              let requirement
        else {
            throw UpdateError.invalidSignature
        }

        let status = SecStaticCodeCheckValidity(code, flags, requirement)
        guard status == errSecSuccess else {
            throw UpdateError.invalidSignature
        }
    }

    nonisolated static func validateUpdateBundle(at appURL: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: appURL),
              let bundleId = bundle.bundleIdentifier,
              QuitXConstants.supportedBundleIdentifiers.contains(bundleId)
        else {
            throw UpdateError.invalidBundle
        }

        if !expectedVersion.isEmpty {
            let bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            guard bundleVersion == expectedVersion else {
                throw UpdateError.versionMismatch
            }
        }

        try validateSignature(of: appURL, expectedTeamIdentifier: currentTeamIdentifier())
    }

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

        return URL(fileURLWithPath: "/Applications/QuitX.app")
    }

    nonisolated static func generateRelaunchScript() -> String {
        return """
        #!/bin/bash
        set -euo pipefail

        TARGET_PID="$1"
        SRC_APP="$2"
        DEST_APP="$3"

        COUNT=0
        while kill -0 "$TARGET_PID" 2>/dev/null; do
            sleep 0.1
            COUNT=$((COUNT + 1))
            if [ "$COUNT" -ge 50 ]; then
                break
            fi
        done

        DEST_DIR="$(dirname "$DEST_APP")"
        NEW_APP="$DEST_DIR/.QuitX.new.$$"
        OLD_APP="$DEST_DIR/.QuitX.old.$$"

        rm -rf "$NEW_APP" "$OLD_APP"

        ditto "$SRC_APP" "$NEW_APP"

        if [ -e "$DEST_APP" ]; then
            mv "$DEST_APP" "$OLD_APP"
        fi

        if mv "$NEW_APP" "$DEST_APP"; then
            rm -rf "$OLD_APP"
        else
            rm -rf "$NEW_APP"

            if [ -e "$OLD_APP" ]; then
                mv "$OLD_APP" "$DEST_APP"
            fi

            exit 1
        fi

        xattr -rd com.apple.quarantine "$DEST_APP" 2>/dev/null || true
        rm -rf "$(dirname "$SRC_APP")"

        open "$DEST_APP"

        rm -- "$0"
        """
    }

    func installAndRelaunch(stagedURL: URL) {

        stagedDirURL = nil

        let destURL = Self.resolveDestinationAppURL()
        let parentDir = destURL.deletingLastPathComponent()

        guard FileManager.default.isWritableFile(atPath: parentDir.path) else {
            let error = UpdateError.destinationNotWritable(parentDir.path)
            state = .failed(message: error.localizedDescription)
            return
        }

        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quitx_relaunch_\(UUID().uuidString).sh")

        do {
            try Self.generateRelaunchScript().write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [
                "-c",
                "nohup \"$@\" >/dev/null 2>&1 &",
                "updater",
                scriptURL.path,
                String(ProcessInfo.processInfo.processIdentifier),
                stagedURL.path,
                destURL.path
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()

            NSApp.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: scriptURL)
            state = .failed(message: "Failed to launch updater: \(error.localizedDescription)")
        }
    }

    private static let bytesFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter
    }()

    private static let speedFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    static func formatBytes(_ bytes: Int64) -> String {
        bytesFormatter.string(fromByteCount: bytes)
    }

    static func formatSpeed(bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "" }
        return "\(speedFormatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
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

        let delta = abs(downloadProgress - lastPublishedProgress)
        let reachedEnd = downloadProgress >= 1.0 && lastPublishedProgress < 1.0
        guard delta >= 0.005 || reachedEnd else { return }
        lastPublishedProgress = downloadProgress
        state = .downloading(
            progress: downloadProgress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            speed: downloadSpeed
        )
    }

    fileprivate func handleDownloadFinished(
        persistentDMG: URL,
        session completedSession: URLSession,
        task completedTask: URLSessionTask
    ) async {
        guard isActive(session: completedSession, task: completedTask) else {
            try? FileManager.default.removeItem(at: persistentDMG.deletingLastPathComponent())
            return
        }
        let version = targetVersion
        let digest = currentDigest
        let edSignature = currentEdSignature
        defer { finishSession(completedSession, task: completedTask) }

        do {
            guard let digest, !digest.isEmpty else {
                throw UpdateError.missingDigest
            }
            guard let edSignature, !edSignature.isEmpty else {
                throw UpdateError.missingSignature
            }

            let dmgURL = persistentDMG
            try await Task.detached {
                try Self.verifyDigest(of: dmgURL, expectedDigest: digest)
                try Self.verifyEdSignature(of: dmgURL, signatureBase64: edSignature)
            }.value

            guard isActive(session: completedSession, task: completedTask) else {
                try? FileManager.default.removeItem(at: persistentDMG.deletingLastPathComponent())
                return
            }

            state = .extracting
            let stagedURL = try await extractAppFromDMG(dmgURL: persistentDMG)
            stagedDirURL = stagedURL.deletingLastPathComponent()

            guard isActive(session: completedSession, task: completedTask) else {
                try? FileManager.default.removeItem(at: stagedURL.deletingLastPathComponent())
                return
            }

            let expectedVersion = version
            try await Task.detached {
                try Self.validateUpdateBundle(at: stagedURL, expectedVersion: expectedVersion)
            }.value

            guard isActive(session: completedSession, task: completedTask) else {
                try? FileManager.default.removeItem(at: stagedURL.deletingLastPathComponent())
                return
            }

            state = .ready(stagedURL: stagedURL, version: version)
        } catch {
            guard isActive(session: completedSession, task: completedTask) else {
                try? FileManager.default.removeItem(at: persistentDMG.deletingLastPathComponent())
                return
            }
            clearStagedDirectory()
            try? FileManager.default.removeItem(at: persistentDMG.deletingLastPathComponent())
            state = .failed(message: error.localizedDescription)
        }
    }

    fileprivate func handleDownloadFailed(error: Error, session failedSession: URLSession, task failedTask: URLSessionTask) {
        guard isActive(session: failedSession, task: failedTask) else { return }
        finishSession(failedSession, task: failedTask)
        if let urlError = error as? URLError, urlError.code == .cancelled {
            state = .idle
            return
        }
        state = .failed(message: error.localizedDescription)
    }
}

extension UpdateDownloadService: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard self.isActive(session: session, task: downloadTask) else { return }
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
        let updateDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXUpdate-\(UUID().uuidString)")
        let persistentDMG = updateDir.appendingPathComponent("QuitX.dmg")

        do {
            try FileManager.default.createDirectory(at: updateDir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: persistentDMG)

            Task { @MainActor in
                await self.handleDownloadFinished(
                    persistentDMG: persistentDMG,
                    session: session,
                    task: downloadTask
                )
            }
        } catch {
            Task { @MainActor in
                guard self.isActive(session: session, task: downloadTask) else { return }
                self.finishSession(session, task: downloadTask)
                self.state = .failed(message: "Failed to process downloaded file: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.handleDownloadFailed(error: error, session: session, task: task)
            }
        }
    }
}
