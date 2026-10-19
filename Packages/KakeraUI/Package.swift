// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KakeraUI",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KakeraUI", targets: ["KakeraUI"])
    ],
    targets: [
        .target(name: "KakeraUI"),
        .testTarget(name: "KakeraUITests", dependencies: ["KakeraUI"])
    ]
)
