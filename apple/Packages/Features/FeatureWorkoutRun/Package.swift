// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureWorkoutRun",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "FeatureWorkoutRun", targets: ["FeatureWorkoutRun"])],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../TimerEngine"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../TestSupport"),
    ],
    targets: [
        .target(name: "FeatureWorkoutRun", dependencies: [
            .product(name: "Domain", package: "Domain"),
            .product(name: "TimerEngine", package: "TimerEngine"),
            .product(name: "DesignSystem", package: "DesignSystem"),
        ]),
        .testTarget(name: "FeatureWorkoutRunTests", dependencies: [
            "FeatureWorkoutRun",
            .product(name: "Domain", package: "Domain"),
            .product(name: "TimerEngine", package: "TimerEngine"),
            .product(name: "TestSupport", package: "TestSupport"),
        ]),
    ]
)
