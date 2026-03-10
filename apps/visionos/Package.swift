// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BitcoinRegimeNavigator",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "BitcoinRegimeDomain",
            targets: ["BitcoinRegimeDomain"]
        ),
        .library(
            name: "BitcoinRegimeUI",
            targets: ["BitcoinRegimeUI"]
        )
    ],
    targets: [
        .target(
            name: "BitcoinRegimeDomain"
        ),
        .target(
            name: "BitcoinRegimeUI",
            dependencies: ["BitcoinRegimeDomain"]
        ),
        .testTarget(
            name: "BitcoinRegimeDomainTests",
            dependencies: ["BitcoinRegimeDomain"]
        )
    ]
)
