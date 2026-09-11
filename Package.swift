// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopyToTranslate",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "CopyToTranslate", targets: ["CopyToTranslate"])],
    targets: [
        .target(name: "ClipboardCore"),
        .executableTarget(name: "CopyToTranslate", dependencies: ["ClipboardCore"]),
        .testTarget(name: "ClipboardCoreTests", dependencies: ["ClipboardCore"]),
        .testTarget(name: "CopyToTranslateTests", dependencies: ["CopyToTranslate", "ClipboardCore"])
    ]
)
