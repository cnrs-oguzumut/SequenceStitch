// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SequenceStitch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SequenceStitch", targets: ["SequenceStitch"])
    ],
    targets: [
        .executableTarget(
            name: "SequenceStitch",
            path: "Sources"
        )
    ]
)
