import Testing
import AppKit
import Foundation
@testable import QuitX

@Suite("App In-App Update Tests")
@MainActor
struct AppUpdateTests {

    private static let releaseJSON = """
    {
        "tag_name": "v9.9.9",
        "name": "QuitX v9.9.9",
        "body": "## Fixes\\n- Faster quits",
        "html_url": "https://github.com/kiron0/quitx/releases/tag/v9.9.9",
        "published_at": "2026-10-20T10:00:00Z",
        "draft": false,
        "prerelease": false,
        "assets": [
            {
                "name": "updates.json",
                "browser_download_url": "https://github.com/kiron0/quitx/releases/download/v9.9.9/updates.json",
                "size": 512
            },
            {
                "name": "QuitX-v9.9.9.zip",
                "browser_download_url": "https://github.com/kiron0/quitx/releases/download/v9.9.9/QuitX-v9.9.9.zip",
                "size": 4000000
            },
            {
                "name": "QuitX-v9.9.9.dmg",
                "browser_download_url": "https://github.com/kiron0/quitx/releases/download/v9.9.9/QuitX-v9.9.9.dmg",
                "size": 4384565,
                "digest": "sha256:0e358a884c81bd1eb7f0ba654ea0193e4289e4253fa2e22918ad1b389b0f40ca"
            }
        ]
    }
    """

    @Test("GitHub release JSON decoding picks the DMG")
    func testGitHubReleaseDecoding() throws {
        let release = try GitHubRelease.decode(Data(Self.releaseJSON.utf8))

        #expect(release.version == "9.9.9")
        #expect(release.htmlUrl?.contains("/releases/tag/v9.9.9") == true)
        let asset = try #require(release.installerAsset)
        #expect(asset.name == "QuitX-v9.9.9.dmg")
        #expect(asset.size == 4384565)
        #expect(asset.digest?.hasPrefix("sha256:") == true)
    }

    @Test("Newer GitHub release becomes an available update")
    func testEvaluateNewerRelease() throws {
        let release = try GitHubRelease.decode(Data(Self.releaseJSON.utf8))
        let update = try #require(try UpdateChecker.evaluate(release: release, currentVersion: "1.1.7").get())

        #expect(update.version == "9.9.9")
        #expect(update.downloadURL.lastPathComponent == "QuitX-v9.9.9.dmg")
        #expect(update.digest?.contains("0e358a88") == true)
        #expect(update.notes?.contains("Faster quits") == true)
    }

    @Test("Same, older, draft and prerelease releases are not offered")
    func testEvaluateIgnoresNonUpdates() throws {
        let release = try GitHubRelease.decode(Data(Self.releaseJSON.utf8))
        #expect(try UpdateChecker.evaluate(release: release, currentVersion: "9.9.9").get() == nil)
        #expect(try UpdateChecker.evaluate(release: release, currentVersion: "10.0.0").get() == nil)

        let draft = Self.releaseJSON.replacingOccurrences(of: "\"draft\": false", with: "\"draft\": true")
        #expect(try UpdateChecker.evaluate(release: GitHubRelease.decode(Data(draft.utf8)), currentVersion: "1.0.0").get() == nil)

        let pre = Self.releaseJSON.replacingOccurrences(of: "\"prerelease\": false", with: "\"prerelease\": true")
        #expect(try UpdateChecker.evaluate(release: GitHubRelease.decode(Data(pre.utf8)), currentVersion: "1.0.0").get() == nil)
    }

    @Test("Release without a DMG or with an insecure URL fails clearly")
    func testEvaluateMissingInstaller() throws {
        let noDmg = Self.releaseJSON.replacingOccurrences(of: "QuitX-v9.9.9.dmg", with: "QuitX-v9.9.9.pkg")
        let release = try GitHubRelease.decode(Data(noDmg.utf8))
        #expect(throws: UpdateCheckError.missingInstaller) {
            try UpdateChecker.evaluate(release: release, currentVersion: "1.0.0").get()
        }

        let insecure = Self.releaseJSON.replacingOccurrences(
            of: "https://github.com/kiron0/quitx/releases/download/v9.9.9/QuitX-v9.9.9.dmg",
            with: "http://github.com/kiron0/quitx/releases/download/v9.9.9/QuitX-v9.9.9.dmg"
        )
        #expect(throws: UpdateCheckError.missingInstaller) {
            try UpdateChecker.evaluate(release: GitHubRelease.decode(Data(insecure.utf8)), currentVersion: "1.0.0").get()
        }
    }

    @Test("Updates come straight from the GitHub Releases API")
    func testLatestReleaseEndpoint() {
        #expect(UpdateChecker.latestReleaseURL.absoluteString == "https://api.github.com/repos/kiron0/quitx/releases/latest")
        #expect(QuitXConstants.releasesPageURL.host == "github.com")
    }

    @Test("Menu title follows update progress")
    func testUpdateMenuTitle() {
        #expect(StatusItemController.updateMenuTitle(availableVersion: nil, state: .idle) == nil)
        #expect(StatusItemController.updateMenuTitle(availableVersion: "2.0.0", state: .idle) == "Update to v2.0.0…")
        #expect(StatusItemController.updateMenuTitle(availableVersion: "2.0.0", state: .extracting) == "Downloading v2.0.0…")
        #expect(
            StatusItemController.updateMenuTitle(
                availableVersion: nil,
                state: .ready(stagedURL: URL(fileURLWithPath: "/tmp/QuitX.app"), version: "2.0.0")
            ) == "Restart to Update to v2.0.0"
        )
    }

    @Test("Update notifications fire once per version and kind")
    func testUpdateNotifierDedup() throws {
        let suite = "quitx-notifier-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(UpdateNotifier.shouldNotify(version: "2.0.0", kind: "available", defaults: defaults))
        defaults.set("available:2.0.0", forKey: "quitx_update_notified_version")
        #expect(!UpdateNotifier.shouldNotify(version: "2.0.0", kind: "available", defaults: defaults))
        #expect(UpdateNotifier.shouldNotify(version: "2.0.0", kind: "ready", defaults: defaults))
        #expect(UpdateNotifier.shouldNotify(version: "2.0.1", kind: "available", defaults: defaults))
    }

    @Test("Update download URLs require HTTPS and a host")
    func testSecureDownloadURLValidation() {
        #expect(UpdateChecker.secureDownloadURL(from: "https://updates.example.com/QuitX.dmg") != nil)
        #expect(UpdateChecker.secureDownloadURL(from: "http://updates.example.com/QuitX.dmg") == nil)
        #expect(UpdateChecker.secureDownloadURL(from: "file:///tmp/QuitX.dmg") == nil)
        #expect(UpdateChecker.secureDownloadURL(from: "not a URL") == nil)
    }

    @Test("Automatic update checks run every six hours")
    func testAutomaticUpdateCheckDelay() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let hour: TimeInterval = 60 * 60

        #expect(UpdateChecker.automaticCheckDelay(lastCheck: nil, now: now) == 0)
        #expect(UpdateChecker.automaticCheckDelay(lastCheck: now.addingTimeInterval(-5 * hour), now: now) == hour)
        #expect(UpdateChecker.automaticCheckDelay(lastCheck: now.addingTimeInterval(-6 * hour), now: now) == 0)
        #expect(UpdateChecker.automaticCheckDelay(lastCheck: now.addingTimeInterval(hour), now: now) == 0)
    }

    @Test("Relaunch Script Generation Syntax and Safety")
    func testRelaunchScriptGeneration() {
        let script = UpdateDownloadService.generateRelaunchScript()

        #expect(script.hasPrefix("#!/bin/bash"))
        #expect(script.contains("set -uo pipefail"))
        #expect(script.contains("TARGET_PID=\"$1\""))
        #expect(script.contains("SRC_APP=\"$2\""))
        #expect(script.contains("DEST_APP=\"$3\""))
        #expect(script.contains("while kill -0 \"$TARGET_PID\" 2>/dev/null; do"))
        #expect(script.contains("ditto \"$SRC_APP\" \"$NEW_APP\""))
        #expect(script.contains("mv \"$DEST_APP\" \"$OLD_APP\""))
        #expect(script.contains("mv \"$NEW_APP\" \"$DEST_APP\""))
        #expect(script.contains("mv \"$OLD_APP\" \"$DEST_APP\""))
        #expect(script.contains("xattr -rd com.apple.quarantine \"$DEST_APP\""))
        #expect(script.contains("/usr/bin/osascript -e \"$ADMIN_SCRIPT\""))
        #expect(script.contains("open \"$DEST_APP\""))
        #expect(script.contains("open \"$CURRENT_APP\""))
        #expect(script.contains("rm -- \"$0\""))
        #expect(!script.contains("kill -9"))
        #expect(!script.contains("/tmp/staged"))
        #expect(!script.contains("/Applications/QuitX.app"))
    }

    @Test("Relaunch script swaps the app and restores on failure")
    func testRelaunchScriptSwapRuns() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("quitx-swap-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let staged = root.appendingPathComponent("staged/QuitX.app")
        let dest = root.appendingPathComponent("Apps/QuitX.app")
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try "new".write(to: staged.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
        try "old".write(to: dest.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
        let scriptURL = root.appendingPathComponent("relaunch.sh")
        try UpdateDownloadService.generateRelaunchScript().write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, "--swap", staged.path, dest.path]
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        #expect(try String(contentsOf: dest.appendingPathComponent("marker"), encoding: .utf8) == "new")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dest.deletingLastPathComponent().path)
        #expect(leftovers == ["QuitX.app"])
    }

    @Test("Admin install command quotes paths safely")
    func testAdminAppleScriptQuoting() {
        let script = UpdateDownloadService.adminAppleScript(
            runningScriptAt: "/tmp/it's here.sh",
            arguments: ["--swap", "/tmp/a \"b\"/QuitX.app", "/Applications/QuitX.app"]
        )
        #expect(script.hasPrefix("do shell script \""))
        #expect(script.hasSuffix("with administrator privileges"))
        #expect(script.contains("'/tmp/it'\\\\''s here.sh'"))
        #expect(script.contains("\\\"b\\\""))
    }

    @Test("Byte Formatting and Speed Calculations")
    func testFormattingHelpers() {
        let byteString = UpdateDownloadService.formatBytes(15 * 1024 * 1024)
        #expect(byteString.contains("MB") || byteString.contains("15"))

        let speedString = UpdateDownloadService.formatSpeed(bytesPerSecond: 3.5 * 1024 * 1024)
        #expect(speedString.contains("/s"))

        let zeroSpeed = UpdateDownloadService.formatSpeed(bytesPerSecond: 0)
        #expect(zeroSpeed.isEmpty)

        let negativeSpeed = UpdateDownloadService.formatSpeed(bytesPerSecond: -100)
        #expect(negativeSpeed.isEmpty)
    }

    @Test("UpdateState Enum Equality and Transitions")
    func testUpdateStateEquality() {
        let idle = UpdateState.idle
        #expect(idle == .idle)

        let downloading1 = UpdateState.downloading(progress: 0.5, bytesDownloaded: 500, totalBytes: 1000, speed: "1 MB/s")
        let downloading2 = UpdateState.downloading(progress: 0.5, bytesDownloaded: 500, totalBytes: 1000, speed: "1 MB/s")
        let downloading3 = UpdateState.downloading(progress: 0.6, bytesDownloaded: 600, totalBytes: 1000, speed: "1.2 MB/s")
        #expect(downloading1 == downloading2)
        #expect(downloading1 != downloading3)

        let extracting = UpdateState.extracting
        #expect(extracting == .extracting)

        let dummyURL = URL(fileURLWithPath: "/tmp/QuitX.app")
        let ready1 = UpdateState.ready(stagedURL: dummyURL, version: "1.1.0")
        let ready2 = UpdateState.ready(stagedURL: dummyURL, version: "1.1.0")
        #expect(ready1 == ready2)

        let failed1 = UpdateState.failed(message: "Network error")
        let failed2 = UpdateState.failed(message: "Network error")
        #expect(failed1 == failed2)
        #expect(failed1 != ready1)
    }

    @Test("UpdateError Descriptions")
    func testUpdateErrorDescriptions() {
        let errors: [UpdateError] = [
            .invalidDownloadURL,
            .downloadFailed("timeout"),
            .mountFailed,
            .copyFailed,
            .appNotFoundInDMG,
            .invalidBundle,
            .destinationNotWritable("/Applications"),
            .scriptExecutionFailed("permission denied"),
            .invalidChecksum,
            .invalidSignature,
            .versionMismatch
        ]

        for err in errors {
            #expect(err.errorDescription != nil)
            #expect(!err.errorDescription!.isEmpty)
        }
    }

    @Test("Resolve Destination Application URL")
    func testResolveDestinationAppURL() {
        let dest = UpdateDownloadService.resolveDestinationAppURL()
        #expect(dest.pathExtension == "app")

        let installed = URL(fileURLWithPath: "/Users/someone/Applications/QuitX.app")
        #expect(UpdateDownloadService.resolveDestinationAppURL(current: installed) == installed)

        let translocated = URL(fileURLWithPath: "/private/var/folders/xy/AppTranslocation/ABC/d/QuitX.app")
        #expect(UpdateDownloadService.resolveDestinationAppURL(current: translocated).lastPathComponent == "QuitX.app")
        #expect(!UpdateDownloadService.resolveDestinationAppURL(current: translocated).path.contains("AppTranslocation"))
    }

    @Test("DMG Mount, Extraction and Bundle Validation Pipeline")
    func testDMGExtractionPipeline() async throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuitXTest-\(UUID().uuidString)")
        let stageDir = tempRoot.appendingPathComponent("stage")
        let fakeAppDir = stageDir.appendingPathComponent("QuitX.app")
        let macosDir = fakeAppDir.appendingPathComponent("Contents/MacOS")
        let infoPlistURL = fakeAppDir.appendingPathComponent("Contents/Info.plist")
        let execURL = macosDir.appendingPathComponent("QuitX")
        let dmgURL = tempRoot.appendingPathComponent("test.dmg")

        try FileManager.default.createDirectory(at: macosDir, withIntermediateDirectories: true)

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>io.coreify.quitx</string>
            <key>CFBundleExecutable</key>
            <string>QuitX</string>
            <key>CFBundleShortVersionString</key>
            <string>9.9.9</string>
        </dict>
        </plist>
        """
        try plistContent.write(to: infoPlistURL, atomically: true, encoding: .utf8)

        let dummyScript = "#!/bin/sh\nexit 0\n"
        try dummyScript.write(to: execURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execURL.path)

        let hdiutilProcess = Process()
        hdiutilProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        hdiutilProcess.arguments = ["create", "-volname", "QuitX", "-srcfolder", stageDir.path, "-ov", "-format", "UDZO", dmgURL.path]
        try hdiutilProcess.run()
        hdiutilProcess.waitUntilExit()
        #expect(hdiutilProcess.terminationStatus == 0)

        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let service = UpdateDownloadService.shared
        let extractedApp = try await service.extractAppFromDMG(dmgURL: dmgURL)

        #expect(FileManager.default.fileExists(atPath: extractedApp.path))
        #expect(extractedApp.lastPathComponent == "QuitX.app")

        let bundle = try #require(Bundle(url: extractedApp))
        #expect(bundle.bundleIdentifier == QuitXConstants.primaryBundleId)

        #expect(throws: UpdateError.invalidSignature) {
            try UpdateDownloadService.validateUpdateBundle(at: extractedApp, expectedVersion: "9.9.9")
        }

        try? FileManager.default.removeItem(at: extractedApp.deletingLastPathComponent())
    }

    @Test("Settings and Excluded Apps Persist Across Updates")
    func testSettingsPersistenceAcrossUpdate() throws {
        let testDefaults = UserDefaults(suiteName: "io.coreify.quitx.test.persistence")!
        defer {
            testDefaults.removePersistentDomain(forName: "io.coreify.quitx.test.persistence")
        }

        let customExclude = ["com.apple.Safari", "com.google.Chrome", "com.tinyspeck.slackmacgap"]
        var initialConfig = QuitXConfig.default
        initialConfig.exclude = customExclude
        initialConfig.neverQuitMusic = false
        initialConfig.sortBy = .name

        let encoded = try JSONEncoder().encode(initialConfig)
        testDefaults.set(encoded, forKey: QuitXConstants.UserDefaultsKeys.config)
        testDefaults.set(["^", "⌥", "Q"], forKey: QuitXConstants.UserDefaultsKeys.quitAllKeys)
        testDefaults.set(true, forKey: QuitXConstants.UserDefaultsKeys.firstLaunchSeen)

        let storedData = try #require(testDefaults.data(forKey: QuitXConstants.UserDefaultsKeys.config))
        let restoredConfig = try JSONDecoder().decode(QuitXConfig.self, from: storedData)

        #expect(restoredConfig.exclude == customExclude)
        #expect(restoredConfig.neverQuitMusic == false)
        #expect(restoredConfig.sortBy == .name)
        #expect(testDefaults.stringArray(forKey: QuitXConstants.UserDefaultsKeys.quitAllKeys) == ["^", "⌥", "Q"])
        #expect(testDefaults.bool(forKey: QuitXConstants.UserDefaultsKeys.firstLaunchSeen) == true)
    }

    @Test("Digest Verification Rejects Mismatched Payloads")
    func testDigestVerification() throws {
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quitx-digest-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try Data("quitx-payload".utf8).write(to: fileURL)

        let actual = try UpdateDownloadService.sha256(of: fileURL)
        #expect(actual.count == 64)

        try UpdateDownloadService.verifyDigest(of: fileURL, expectedDigest: actual)
        try UpdateDownloadService.verifyDigest(of: fileURL, expectedDigest: "sha256:\(actual.uppercased())")
        try UpdateDownloadService.verifyDigest(of: fileURL, expectedDigest: "")

        #expect(throws: UpdateError.invalidChecksum) {
            try UpdateDownloadService.verifyDigest(
                of: fileURL,
                expectedDigest: String(repeating: "0", count: 64)
            )
        }
    }

    @Test("Update Digest Normalization")
    func testDigestNormalization() {
        #expect(UpdateDownloadService.normalizedDigest("sha256:ABC123") == "abc123")
        #expect(UpdateDownloadService.normalizedDigest("  abc123\n") == "abc123")
    }

    @Test("Unsigned Update Bundle Is Rejected")
    func testUnsignedBundleRejected() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quitx-unsigned-\(UUID().uuidString).app")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("Contents"),
            withIntermediateDirectories: true
        )

        #expect(throws: UpdateError.invalidSignature) {
            try UpdateDownloadService.validateSignature(of: tempDir, requirement: nil)
        }
    }

    @Test("Update Bundle Version And Identifier Validation")
    func testValidateUpdateBundleChecksVersionAndIdentifier() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quitx-bundle-\(UUID().uuidString)")
        let appDir = tempRoot.appendingPathComponent("QuitX.app")
        let contentsDir = appDir.appendingPathComponent("Contents")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>io.coreify.quitx</string>
            <key>CFBundleShortVersionString</key>
            <string>9.9.9</string>
        </dict>
        </plist>
        """
        try plistContent.write(
            to: contentsDir.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )

        #expect(throws: UpdateError.versionMismatch) {
            try UpdateDownloadService.validateUpdateBundle(at: appDir, expectedVersion: "1.0.0")
        }

        #expect(throws: UpdateError.invalidSignature) {
            try UpdateDownloadService.validateUpdateBundle(at: appDir, expectedVersion: "9.9.9")
        }
    }
}
