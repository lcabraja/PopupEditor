// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PopupEditor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PopupEditor", targets: ["PopupEditor"])
    ],
    targets: [
        .executableTarget(
            name: "PopupEditor",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
