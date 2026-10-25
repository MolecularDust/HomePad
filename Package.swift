// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HomePad",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HomePad",
            path: "Sources/HomePad"
        )
    ]
)
