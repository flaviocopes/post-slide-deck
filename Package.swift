// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Postdeck",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "PostdeckCore", targets: ["PostdeckCore"]),
    .executable(name: "PostdeckApp", targets: ["PostdeckApp"])
  ],
  targets: [
    .target(name: "PostdeckCore"),
    .executableTarget(
      name: "PostdeckApp",
      dependencies: ["PostdeckCore"]
    ),
    .testTarget(
      name: "PostdeckCoreTests",
      dependencies: ["PostdeckCore"]
    )
  ]
)
