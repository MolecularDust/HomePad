// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpotlightPlus",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SpotlightPlus",
            path: "Sources/SpotlightPlus"
        )
    ]
)
