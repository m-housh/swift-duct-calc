// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-manual-d",
  products: [
    .library(name: "swift-manual-d", targets: ["swift-manual-d"]),
    .library(name: "ManualDCore", targets: ["ManualDCore"]),
    .library(name: "ManualDClient", targets: ["ManualDClient"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "swift-manual-d"
    ),
    .target(
      name: "ManualDCore"
    ),
    .target(
      name: "ManualDClient",
      dependencies: [
        "ManualDCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "ManualDClientTests",
      dependencies: ["ManualDClient"]
    ),
    .testTarget(
      name: "swift-manual-dTests",
      dependencies: ["swift-manual-d"]
    ),
  ]
)
