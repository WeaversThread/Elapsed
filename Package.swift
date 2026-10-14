// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Elapsed",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Elapsed",
            path: "StatusTimer",
            exclude: ["Info.plist", "StatusTimer.entitlements"],
            resources: [
                .copy("Resources"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "StatusTimer/Info.plist",
                ]),
            ]
        ),
    ]
)
