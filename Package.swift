// swift-tools-version: 5.9
import PackageDescription
import Foundation

// On machines with only the Command Line Tools installed, Swift Testing lives in
// /Library/Developer/CommandLineTools/Library/Developer/Frameworks instead of the
// toolchain's default search path. Xcode installations do not need (and must not
// get) these flags, so add them only when that layout is actually detected.
let cltTestingFrameworkPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let needsCLTTestingSearchPath = FileManager.default.fileExists(
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
