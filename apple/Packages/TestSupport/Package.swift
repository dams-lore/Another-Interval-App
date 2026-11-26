// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestSupport",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [.library(name: "TestSupport", targets: ["TestSupport"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "TestSupport", dependencies: [.product(name: "Domain", package: "Domain")]),
        .testTarget(name: "TestSupportTests", dependencies: [
            "TestSupport",
            .product(name: "Domain", package: "Domain"),
        ]),
    ]
)
