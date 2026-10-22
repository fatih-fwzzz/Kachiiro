// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KachiiroCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "KachiiroCore", targets: ["KachiiroCore"])
    ],
    targets: [
        .target(name: "KachiiroCore"),
        .testTarget(
            name: "KachiiroCoreTests",
            dependencies: ["KachiiroCore"],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5]
)
