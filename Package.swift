// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "LiveTranslatorCore",
    platforms: [.macOS(.v26)],
    products: [.library(name: "LiveTranslatorCore", targets: ["LiveTranslatorCore"])],
    targets: [
        .target(name: "LiveTranslatorCore", path: "LiveTranslator", exclude: ["App", "Views"]),
        .testTarget(name: "LiveTranslatorCoreTests", dependencies: ["LiveTranslatorCore"], path: "Tests")
    ]
)
