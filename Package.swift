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
            path: "Tests/QuitXTests"
        ),
    ]
)
