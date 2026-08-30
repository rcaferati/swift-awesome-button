// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "swift-awesome-button",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    .library(
      name: "SwiftAwesomeButton",
      targets: ["SwiftAwesomeButton"]
    )
  ],
  targets: [
    .target(
      name: "SwiftAwesomeButton",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "SwiftAwesomeButtonTests",
      dependencies: ["SwiftAwesomeButton"]
    ),
  ]
)
