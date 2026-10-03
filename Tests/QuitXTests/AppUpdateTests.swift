import Testing
import AppKit
import Foundation
@testable import QuitX

@Suite("App In-App Update Tests")
@MainActor
struct AppUpdateTests {

    @Test("GitHub Release JSON Decoding and DMG Asset Extraction")
    func testReleaseDecodingAndAssetExtraction() throws {
        let json = """
        {
            "tag_name": "v1.1.0",
            "name": "QuitX v1.1.0",
            "html_url": "https://github.com/coreify-dev/quitx/releases/tag/v1.1.0",
            "assets": [
                {
                    "name": "source.zip",
                    "browser_download_url": "https://github.com/coreify-dev/quitx/releases/download/v1.1.0/source.zip",
                    "size": 1024
                },
                {
                    "name": "QuitX-v1.1.0.dmg",
                    "browser_download_url": "https://github.com/coreify-dev/quitx/releases/download/v1.1.0/QuitX-v1.1.0.dmg",
                    "size": 25000000
                }
            ]
        }
        """

        let data = try #require(json.data(using: .utf8))
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        #expect(release.tag_name == "v1.1.0")
        #expect(release.assets?.count == 2)

        let dmgAsset = UpdateChecker.extractDMGAsset(from: release.assets)
        let found = try #require(dmgAsset)
        #expect(found.name == "QuitX-v1.1.0.dmg")
        #expect(found.browser_download_url == "https://github.com/coreify-dev/quitx/releases/download/v1.1.0/QuitX-v1.1.0.dmg")
        #expect(found.size == 25000000)
    }

    @Test("DMG Asset Missing Returns Nil")
    func testMissingDMGAsset() throws {
        let assets = [
            GitHubReleaseAsset(name: "archive.zip", browser_download_url: "https://example.com/archive.zip", size: 100),
            GitHubReleaseAsset(name: "notes.txt", browser_download_url: "https://example.com/notes.txt", size: 50)
        ]

        let extracted = UpdateChecker.extractDMGAsset(from: assets)
        #expect(extracted == nil)

        let emptyExtract = UpdateChecker.extractDMGAsset(from: nil)
        #expect(emptyExtract == nil)
    }

    @Test("Relaunch Script Generation Syntax and Safety")
    func testRelaunchScriptGeneration() {
        let pid: Int32 = 12345
        let src = "/tmp/staged/QuitX.app"
        let dest = "/Applications/QuitX.app"

        let script = UpdateDownloadService.generateRelaunchScript(targetPID: pid, srcAppPath: src, destAppPath: dest)

        #expect(script.contains("#!/bin/bash"))
        #expect(script.contains("TARGET_PID=12345"))
        #expect(script.contains("SRC_APP=\"/tmp/staged/QuitX.app\""))
        #expect(script.contains("DEST_APP=\"/Applications/QuitX.app\""))
        #expect(script.contains("while kill -0 \"$TARGET_PID\" 2>/dev/null; do"))
        #expect(script.contains("rm -rf \"$DEST_APP\""))
        #expect(script.contains("ditto \"$SRC_APP\" \"$DEST_APP\""))
        #expect(script.contains("xattr -rd com.apple.quarantine \"$DEST_APP\""))
        #expect(script.contains("open \"$DEST_APP\""))
        #expect(script.contains("rm -- \"$0\""))
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
            .scriptExecutionFailed("permission denied")
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
}
