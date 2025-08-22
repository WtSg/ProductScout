// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "ProductScout",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "ProductScout",
            targets: ["BestBuyTracker"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "BestBuyTracker",
            dependencies: ["SwiftSoup"],
            path: "Sources"
        )
    ]
)