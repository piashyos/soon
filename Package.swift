// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Soon",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Soon"),
        .testTarget(name: "SoonTests", dependencies: ["Soon"]),
    ]
)
