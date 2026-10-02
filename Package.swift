// swift-tools-version: 5.9
import PackageDescription

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
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-F", "/Applications/Xcode_16.0.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-F", "/Applications/Xcode_16.0.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-framework", "Testing"
                ])
            ]
        ),
    ]
)
