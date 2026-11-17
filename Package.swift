// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cambio",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CambioCore"),
        .executableTarget(name: "Cambio", dependencies: ["CambioCore"]),
        .testTarget(name: "CambioCoreTests", dependencies: ["CambioCore"]),
    ]
)
