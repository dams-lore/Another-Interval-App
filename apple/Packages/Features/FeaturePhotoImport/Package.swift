// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeaturePhotoImport",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "FeaturePhotoImport", targets: ["FeaturePhotoImport"])],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../TestSupport"),
    ],
    targets: [
        .target(name: "FeaturePhotoImport", dependencies: [
            .product(name: "Domain", package: "Domain"),
            .product(name: "DesignSystem", package: "DesignSystem"),
        ]),
        .testTarget(name: "FeaturePhotoImportTests", dependencies: [
            "FeaturePhotoImport",
            .product(name: "Domain", package: "Domain"),
            .product(name: "TestSupport", package: "TestSupport"),
        ]),
    ]
)
