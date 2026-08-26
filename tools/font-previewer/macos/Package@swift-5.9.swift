// swift-tools-version: 5.9
import PackageDescription

let excludedCoreSources = [
    "TextTransform.swift",
    "StudyFilter.swift",
    "PathResolver.swift",
    "ExportPlanner.swift",
]

var products: [Product] = [
    .library(name: "FontPreviewerCore", targets: ["FontPreviewerCore"]),
]

var targets: [Target] = [
    .target(
        name: "FontPreviewerCore",
        path: "Sources/FontPreviewerCore",
        exclude: excludedCoreSources
    ),
    .testTarget(
        name: "FontPreviewerCoreTests",
        dependencies: ["FontPreviewerCore"],
        path: "Tests/FontPreviewerCoreTests"
    ),
]

#if os(macOS)
products.append(.executable(name: "FontPreviewer", targets: ["FontPreviewerApp"]))
targets.append(
    .executableTarget(
        name: "FontPreviewerApp",
        dependencies: ["FontPreviewerCore"],
        path: "Sources/FontPreviewerApp"
    )
)
#endif

let package = Package(
    name: "PitchFontPreviewer",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
