// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GlobeSwitch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GlobeSwitch",
            path: "Sources/GlobeSwitch",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
