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
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-url-routing.git", from: "0.6.2"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.6.0"),
  ],
  targets: [
    .target(
      name: "swift-manual-d"
    ),
    .target(
      name: "ManualDCore",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "URLRouting", package: "swift-url-routing"),
        .product(name: "CasePaths", package: "swift-case-paths"),
      ]
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
      dependencies: [
        "ManualDClient",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "ApiRouteTests",
      dependencies: [
        .target(name: "ManualDCore")
      ]
    ),
  ]
)
