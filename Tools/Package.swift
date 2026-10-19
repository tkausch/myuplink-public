// swift-tools-version: 6.0
// Build-time tooling only; not a dependency of the MyUplink library.
import PackageDescription

let package = Package(
    name: "Tools",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.14.0"),
    ]
)
