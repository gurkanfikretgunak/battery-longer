// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatteryLonger",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "BatteryLonger",
            path: "Sources/BatteryLonger",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
