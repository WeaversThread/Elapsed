// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Elapsed",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Elapsed",
            path: "StatusTimer",
            // build.sh copies Resources into the app bundle itself. A SwiftPM resource
            // bundle is only found through this machine's build path, so it's not used.
            exclude: ["Info.plist", "Resources", "Elapsed.entitlements", "Elapsed-AppStore.entitlements"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "StatusTimer/Info.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "ElapsedTests",
            dependencies: ["Elapsed"],
            path: "Tests/ElapsedTests"
        ),
    ]
)
