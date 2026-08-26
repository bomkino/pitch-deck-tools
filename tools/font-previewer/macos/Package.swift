// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [
    .library(name: "FontPreviewerCore", targets: ["FontPreviewerCore"]),
]

var targets: [Target] = [
    .target(
        name: "FontPreviewerCore",
        path: "Sources/FontPreviewerCore"
    ),
    .testTarget(
        name: "FontPreviewerCoreTests",
        dependencies: ["FontPreviewerCore"],
        path: "Tests/FontPreviewerCoreTests"
    ),
]

#if os(macOS)
products += [
    .library(name: "FontPreviewerMacKit", targets: ["FontPreviewerMacKit"]),
    .executable(name: "FontPreviewer", targets: ["FontPreviewerApp"]),
    .executable(name: "FontPreviewerSmoke", targets: ["FontPreviewerSmoke"]),
]

targets += [
    .target(
        name: "FontPreviewerMacKit",
        dependencies: ["FontPreviewerCore"],
        path: "Sources/FontPreviewerMacKit"
    ),
    .executableTarget(
        name: "FontPreviewerApp",
        dependencies: ["FontPreviewerCore", "FontPreviewerMacKit"],
        path: "Sources/FontPreviewerApp"
    ),
    .executableTarget(
        name: "FontPreviewerSmoke",
        dependencies: ["FontPreviewerCore", "FontPreviewerMacKit"],
        path: "Sources/FontPreviewerSmoke"
    ),
    .testTarget(
        name: "FontPreviewerMacKitTests",
        dependencies: ["FontPreviewerCore", "FontPreviewerMacKit"],
        path: "Tests/FontPreviewerMacKitTests"
    ),
]
#endif

let package = Package(
    name: "PitchFontPreviewer",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
