// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiuYao",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LiuYaoCore", targets: ["LiuYaoCore"])],
    dependencies: [
        .package(url: "https://github.com/6tail/lunar-swift.git", revision: "2397017c78a3a1adcb1166952aba4069955a41d1")
    ],
    targets: [
        .target(name: "LiuYaoCore", dependencies: [.product(name: "LunarSwift", package: "lunar-swift")], resources: [.process("Resources")]),
        .testTarget(name: "LiuYaoCoreTests", dependencies: ["LiuYaoCore"])
    ]
)
