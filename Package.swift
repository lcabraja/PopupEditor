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
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/PopupEditor/Info.plist",
                ])
            ]
        )
    ]
)
