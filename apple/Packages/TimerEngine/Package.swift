// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimerEngine",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [.library(name: "TimerEngine", targets: ["TimerEngine"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../TestSupport"),
    ],
    targets: [
        .target(name: "TimerEngine", dependencies: [.product(name: "Domain", package: "Domain")]),
        .testTarget(name: "TimerEngineTests", dependencies: [
            "TimerEngine",
            .product(name: "Domain", package: "Domain"),
            .product(name: "TestSupport", package: "TestSupport"),
        ]),
    ]
)
