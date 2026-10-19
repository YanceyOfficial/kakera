// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KakeraServices",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KakeraServices", targets: ["KakeraServices"])
    ],
    dependencies: [
        .package(path: "../KakeraFSRS")
    ],
    targets: [
        .target(name: "KakeraServices", dependencies: ["KakeraFSRS"]),
        .testTarget(name: "KakeraServicesTests", dependencies: ["KakeraServices"])
    ]
)
