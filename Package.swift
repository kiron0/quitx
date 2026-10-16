// swift-tools-version: 5.10
import PackageDescription
import Foundation

let cltTestingFrameworkPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

let isXcodeActive: Bool = {
    if let devDir = ProcessInfo.processInfo.environment["DEVELOPER_DIR"], devDir.contains(".app") {
        return true
    }
    if ProcessInfo.processInfo.environment["XCODE_VERSION_ACTUAL"] != nil {
        return true
    }
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    process.standardOutput = pipe
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.contains(".app")
        }
    } catch {
        return false
    }
    return false
}()

let needsCLTTestingSearchPath = !isXcodeActive && FileManager.default.fileExists(
    atPath: cltTestingFrameworkPath + "/Testing.framework"
)

var testSwiftSettings: [SwiftSetting] = []
var testLinkerSettings: [LinkerSetting] = []

if needsCLTTestingSearchPath {
    testSwiftSettings = [
        .unsafeFlags(["-F", cltTestingFrameworkPath])
    ]
    testLinkerSettings = [
        .unsafeFlags([
            "-F", cltTestingFrameworkPath,
            "-framework", "Testing",
            "-Xlinker", "-rpath", "-Xlinker", cltTestingFrameworkPath,
            "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
        ])
    ]
}

let package = Package(
    name: "QuitX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "QuitX", targets: ["QuitX"]),
    ],
    targets: [
        .executableTarget(
            name: "QuitX",
            path: "Sources/QuitX"
        ),

        .testTarget(
            name: "QuitXTests",
            dependencies: ["QuitX"],
            path: "Tests/QuitXTests",
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ]
)
