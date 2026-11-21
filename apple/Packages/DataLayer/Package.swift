// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DataLayer",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [.library(name: "DataLayer", targets: ["DataLayer"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Backend"),
    ],
    targets: [
        .target(name: "DataLayer", dependencies: [
            .product(name: "Domain", package: "Domain"),
            .product(name: "Backend", package: "Backend"),
        ]),
        .testTarget(name: "DataLayerTests", dependencies: ["DataLayer"]),
    ]
)
