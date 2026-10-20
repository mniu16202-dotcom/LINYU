// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LinYuCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "LinYuCore", targets: ["LinYuCore"])
    ],
    targets: [
        .target(name: "LinYuCore"),
        .testTarget(name: "LinYuCoreTests", dependencies: ["LinYuCore"])
    ]
)
