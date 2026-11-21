// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Platform",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [.library(name: "Platform", targets: ["Platform"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Platform", dependencies: [.product(name: "Domain", package: "Domain")]),
        .testTarget(name: "PlatformTests", dependencies: [
            "Platform",
            .product(name: "Domain", package: "Domain"),
        ]),
    ]
)
