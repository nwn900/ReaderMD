// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ReaderMD",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ReaderMD", targets: ["ReaderMD"])
    ],
    targets: [
        .executableTarget(
            name: "ReaderMD",
            resources: [
                .copy("Resources/Renderer")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .target(
            name: "ReaderMDQuickLook",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Quartz"),
                .linkedFramework("WebKit"),
            ]
        ),
        .testTarget(
            name: "ReaderMDTests",
            dependencies: ["ReaderMD", "ReaderMDQuickLook"]
        )
    ]
)
