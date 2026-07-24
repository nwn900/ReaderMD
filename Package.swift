// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PreviewMD",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PreviewMD", targets: ["PreviewMD"])
    ],
    targets: [
        .executableTarget(
            name: "PreviewMD",
            resources: [
                .copy("Resources/Renderer")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "PreviewMDTests",
            dependencies: ["PreviewMD"]
        )
    ]
)
