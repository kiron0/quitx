import Testing
import AppKit
import CryptoKit
import Foundation
@testable import QuitX

@Suite("App In-App Update Tests")
@MainActor
struct AppUpdateTests {

    @Test("Gatekeeper Release JSON Decoding")
    func testGatekeeperReleaseDecoding() throws {
        let json = """
        {
            "version": "1.0.4",
            "releaseName": "v1.0.4",
            "releaseNotes": "Fixes and improvements",
            "publishedAt": "2026-10-03T17:37:26Z",
            "downloadUrl": "https://updates.example.com/download/12345",
            "sizeBytes": 4384565,
            "fileName": "QuitX-v1.0.4.dmg",
            "digest": "sha256:0e358a884c81bd1eb7f0ba654ea0193e4289e4253fa2e22918ad1b389b0f40ca",
            "edSignature": "9jIudgPRP0VpRrpXscyEo7rEiJigKHIDNgzwuEh65yDSM/u0IUOgpeBi1sJ/ah399Purw26UGBk3A55E3Kn/BQ=="
        }
        """

        let data = try #require(json.data(using: .utf8))
        let release = try JSONDecoder().decode(GatekeeperRelease.self, from: data)

        #expect(release.version == "1.0.4")
        #expect(release.releaseName == "v1.0.4")
        #expect(release.sizeBytes == 4384565)
        #expect(release.downloadUrl.contains("/download/12345"))
        #expect(release.digest?.contains("sha256") == true)
        #expect(release.edSignature?.isEmpty == false)
    }

    @Test("Update download URLs require HTTPS and a host")
    func testSecureDownloadURLValidation() {
        #expect(UpdateChecker.secureDownloadURL(from: "https://updates.example.com/QuitX.dmg") != nil)
        #expect(UpdateChecker.secureDownloadURL(from: "http://updates.example.com/QuitX.dmg") == nil)
        #expect(UpdateChecker.secureDownloadURL(from: "file:///tmp/QuitX.dmg") == nil)
        #expect(UpdateChecker.secureDownloadURL(from: "not a URL") == nil)
    }

    @Test("Relaunch Script Generation Syntax and Safety")
    func testRelaunchScriptGeneration() {
        let script = UpdateDownloadService.generateRelaunchScript()

        #expect(script.hasPrefix("#!/bin/bash"))
        #expect(script.contains("set -euo pipefail"))
        #expect(script.contains("TARGET_PID=\"$1\""))
        #expect(script.contains("SRC_APP=\"$2\""))
        #expect(script.contains("DEST_APP=\"$3\""))
        #expect(script.contains("while kill -0 \"$TARGET_PID\" 2>/dev/null; do"))
        #expect(script.contains("ditto \"$SRC_APP\" \"$NEW_APP\""))
        #expect(script.contains("mv \"$DEST_APP\" \"$OLD_APP\""))
        #expect(script.contains("mv \"$NEW_APP\" \"$DEST_APP\""))
        #expect(script.contains("xattr -rd com.apple.quarantine \"$DEST_APP\""))
        #expect(script.contains("open \"$DEST_APP\""))
        #expect(script.contains("rm -- \"$0\""))
        #expect(!script.contains("kill -9"))
        #expect(!script.contains("/tmp/staged"))
        #expect(!script.contains("/Applications/QuitX.app"))
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
        #expect(dest.lastPathComponent == "QuitX.app")
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
        #expect(bundle.bundleIdentifier == "io.coreify.quitx")

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
        testDefaults.set(encoded, forKey: "QuitXConfig")
        testDefaults.set(["^", "⌥", "Q"], forKey: "sc_quit_keys")
        testDefaults.set(true, forKey: "quitx_first_launch_seen_v1")

        let storedData = try #require(testDefaults.data(forKey: "QuitXConfig"))
        let restoredConfig = try JSONDecoder().decode(QuitXConfig.self, from: storedData)

        #expect(restoredConfig.exclude == customExclude)
        #expect(restoredConfig.neverQuitMusic == false)
        #expect(restoredConfig.sortBy == .name)
        #expect(testDefaults.stringArray(forKey: "sc_quit_keys") == ["^", "⌥", "Q"])
        #expect(testDefaults.bool(forKey: "quitx_first_launch_seen_v1") == true)
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
            try UpdateDownloadService.validateSignature(of: tempDir, expectedTeamIdentifier: nil)
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

    @Test("Ed25519 Publisher Signature Verification")
    func testEdSignatureVerification() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()

        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quitx-ed25519-\(UUID().uuidString).dmg")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let payload = Data("quitx update payload".utf8)
        try payload.write(to: fileURL)

        let signature = try privateKey.signature(for: payload).base64EncodedString()
        try UpdateDownloadService.verifyEdSignature(
            of: fileURL,
            signatureBase64: signature,
            publicKeyBase64: publicKeyBase64
        )

        try Data("tampered payload".utf8).write(to: fileURL)
        #expect(throws: UpdateError.invalidSignature) {
            try UpdateDownloadService.verifyEdSignature(
                of: fileURL,
                signatureBase64: signature,
                publicKeyBase64: publicKeyBase64
            )
        }

        try payload.write(to: fileURL)
        let otherKey = Curve25519.Signing.PrivateKey()
        let otherSignature = try otherKey.signature(for: payload).base64EncodedString()
        #expect(throws: UpdateError.invalidSignature) {
            try UpdateDownloadService.verifyEdSignature(
                of: fileURL,
                signatureBase64: otherSignature,
                publicKeyBase64: publicKeyBase64
            )
        }

        #expect(throws: UpdateError.invalidSignature) {
            try UpdateDownloadService.verifyEdSignature(
                of: fileURL,
                signatureBase64: "not-base64-signature",
                publicKeyBase64: publicKeyBase64
            )
        }
    }
}
