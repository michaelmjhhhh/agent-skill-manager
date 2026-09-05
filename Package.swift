// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkillHub",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SkillHub", targets: ["SkillHub"])],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1")
    ],
    targets: [
        .executableTarget(name: "SkillHub", dependencies: [
            .product(name: "MarkdownUI", package: "swift-markdown-ui")
        ]),
        .testTarget(name: "SkillHubTests", dependencies: ["SkillHub"])
    ]
)
