import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "AnotherInterval",
    packages: [
        .local(path: "../../Packages/Domain"),
        .local(path: "../../Packages/TimerEngine"),
        .local(path: "../../Packages/DesignSystem"),
        .local(path: "../../Packages/Platform"),
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
            ]),
            sources: ["Sources/**"],
            dependencies: [
                .package(product: "Domain", type: .runtime),
                .package(product: "TimerEngine", type: .runtime),
                .package(product: "DesignSystem", type: .runtime),
                .package(product: "Platform", type: .runtime),
                .package(product: "FeatureWorkoutRun", type: .runtime),
            ],
            settings: strictSettings
        ),
        .target(
            name: "AnotherIntervalTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.anotherinterval.ios.tests",
            deploymentTargets: iOSDeploymentTarget,
            sources: ["Tests/**"],
            dependencies: [.target(name: "AnotherInterval")],
            settings: strictSettings
        ),
    ]
)
