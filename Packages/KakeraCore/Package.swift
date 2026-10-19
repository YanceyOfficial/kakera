// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KakeraCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KakeraCore", targets: ["KakeraCore"])
    ],
    dependencies: [
        .package(path: "../KakeraFSRS")
    ],
    targets: [
        .target(name: "KakeraCore", dependencies: ["KakeraFSRS"]),
        .testTarget(name: "KakeraCoreTests", dependencies: ["KakeraCore"])
    ]
)
