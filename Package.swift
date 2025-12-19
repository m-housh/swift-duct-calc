// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-manual-d",
  products: [
    .library(name: "swift-manual-d", targets: ["swift-manual-d"]),
    .library(name: "ManualDCore", targets: ["ManualDCore"]),
  ],
  targets: [
    .target(
      name: "swift-manual-d"
    ),
    .target(
      name: "ManualDCore"
    ),
    .testTarget(
      name: "swift-manual-dTests",
      dependencies: ["swift-manual-d"]
    ),
  ]
)
