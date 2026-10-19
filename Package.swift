// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyUplink",
    platforms: [
        .macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "MyUplink", targets: ["MyUplink"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/mattt/Replay.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "MyUplink",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ]
        ),
        .testTarget(
            name: "MyUplinkTests",
            dependencies: [
                "MyUplink",
                .product(name: "Replay", package: "Replay"),
            ],
            resources: [
                .copy("Replays"),
            ]
        ),
    ]
)
