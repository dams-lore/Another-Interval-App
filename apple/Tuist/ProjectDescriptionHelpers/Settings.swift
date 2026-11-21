import ProjectDescription

/// Réglages communs à toutes les cibles : Swift 6 strict, iOS 18.
public let strictSettings: Settings = .settings(
    base: [
        "SWIFT_VERSION": "6.0",
        "SWIFT_STRICT_CONCURRENCY": "complete",
    ],
    configurations: [
        .debug(name: "Debug"),
        .release(name: "Release"),
    ]
)

public let iOSDeploymentTarget: DeploymentTargets = .iOS("18.0")
