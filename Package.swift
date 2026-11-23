// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TileForge", platforms: [.macOS(.v14)], products: [.executable(name: "TileForge", targets: ["TileForge"])], targets: [.target(name: "TileCore"), .executableTarget(name: "TileForge", dependencies: ["TileCore"]), .executableTarget(name: "ForgeCheck", dependencies: ["TileCore"]), .testTarget(name: "TileCoreTests", dependencies: ["TileCore", "TileForge"])], swiftLanguageModes: [.v5])
