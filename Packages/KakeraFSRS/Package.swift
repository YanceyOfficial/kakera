// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KakeraFSRS",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KakeraFSRS", targets: ["KakeraFSRS"])
    ],
    targets: [
        .target(name: "KakeraFSRS"),
        .testTarget(name: "KakeraFSRSTests", dependencies: ["KakeraFSRS"])
    ]
)
