// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KakeraAI",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KakeraAI", targets: ["KakeraAI"])
    ],
    dependencies: [
        .package(path: "../KakeraCore")
    ],
    targets: [
        .target(name: "KakeraAI", dependencies: ["KakeraCore"]),
        .testTarget(name: "KakeraAITests", dependencies: ["KakeraAI"])
    ]
)
