import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "AnotherInterval",
    packages: [
        .local(path: "../../Packages/Domain"),
        .local(path: "../../Packages/TimerEngine"),
        .local(path: "../../Packages/DesignSystem"),
        .local(path: "../../Packages/Platform"),
        .local(path: "../../Packages/TestSupport"),
        .local(path: "../../Packages/Backend"),
        .local(path: "../../Packages/DataLayer"),
        .local(path: "../../Packages/Features/FeaturePhotoImport"),
        .local(path: "../../Packages/Features/FeatureWorkoutRun"),
    ],
    targets: [
        .target(
            name: "AnotherInterval",
            destinations: .iOS,
            product: .app,
            bundleId: "app.anotherinterval.ios",
            deploymentTargets: iOSDeploymentTarget,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Another Interval",
                "UILaunchScreen": [:],
                "AnthropicAPIKey": "$(ANTHROPIC_API_KEY)",
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .package(product: "Domain", type: .runtime),
                .package(product: "TimerEngine", type: .runtime),
                .package(product: "DesignSystem", type: .runtime),
                .package(product: "Platform", type: .runtime),
                .package(product: "Backend", type: .runtime),
                .package(product: "DataLayer", type: .runtime),
                .package(product: "FeaturePhotoImport", type: .runtime),
                .package(product: "FeatureWorkoutRun", type: .runtime),
            ],
            settings: appSettings(debug: "Config/Debug.xcconfig", release: "Config/Release.xcconfig")
        ),
        .target(
            name: "AnotherIntervalTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.anotherinterval.ios.tests",
            deploymentTargets: iOSDeploymentTarget,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "AnotherInterval"),
                .package(product: "TestSupport", type: .runtime),
            ],
            settings: strictSettings
        ),
    ]
)
