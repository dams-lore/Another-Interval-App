// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Backend",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [.library(name: "Backend", targets: ["Backend"])],
    dependencies: [
    ],
    targets: [
        .target(name: "Backend", dependencies: []),
        .testTarget(name: "BackendTests", dependencies: ["Backend"]),
    ]
)
