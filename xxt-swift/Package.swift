// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xxt-swift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "XXTCore", targets: ["XXTCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.8.0"))
    ],
    targets: [
        .target(
            name: "XXTCore",
            dependencies: [
                "SwiftSoup",
                "CryptoSwift"
            ]
        ),
        .executableTarget(
            name: "XXTTest",
            dependencies: ["XXTCore"]
        ),
        .testTarget(
            name: "XXTCoreTests",
            dependencies: ["XXTCore"]
        ),
    ]
)
