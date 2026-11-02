// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AnimationReconstruction", platforms: [.iOS(.v16), .macOS(.v13)], products: [.library(name: "AnimationCore", targets: ["AnimationCore"])], targets: [.target(name: "AnimationCore"), .testTarget(name: "AnimationCoreTests", dependencies: ["AnimationCore"], resources: [.copy("Fixtures")])])
