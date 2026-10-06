// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "TennisCore",
  platforms: [
    .iOS(.v26),
    .watchOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(name: "TennisCore", targets: ["TennisCore"])
  ],
  targets: [
    .target(name: "TennisCore"),
    .testTarget(name: "TennisCoreTests", dependencies: ["TennisCore"]),
  ],
  swiftLanguageModes: [.v6]
)
