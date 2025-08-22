// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ObsidianTodoMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ObsidianTodoMac", targets: ["ObsidianTodoMac"])
    ],
    dependencies: [
        // 如果需要第三方依赖可以在这里添加
    ],
    targets: [
        .executableTarget(
            name: "ObsidianTodoMac",
            dependencies: [],
            path: "Sources"
        )
    ]
)