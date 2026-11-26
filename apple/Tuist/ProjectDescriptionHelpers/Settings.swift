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

/// Réglages de l'app : Swift 6 strict + un fichier .xcconfig par configuration (clés de dev hors du code).
public func appSettings(debug: Path, release: Path) -> Settings {
    .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        ],
        configurations: [
            .debug(name: "Debug", xcconfig: debug),
            .release(name: "Release", xcconfig: release),
        ]
    )
}
