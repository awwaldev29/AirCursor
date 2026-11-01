// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AirCursorKit",
    platforms: [.macOS(.v15), .watchOS(.v10)],
    products: [
        .library(name: "AirCursorKit", targets: ["AirCursorKit"]),
    ],
    targets: [
        .target(name: "AirCursorKit"),
        .testTarget(name: "AirCursorKitTests", dependencies: ["AirCursorKit"]),
    ]
)
