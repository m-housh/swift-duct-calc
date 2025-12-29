// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-manual-d",
  products: [
    .library(name: "ManualDCore", targets: ["ManualDCore"]),
    .library(name: "ManualDClient", targets: ["ManualDClient"]),
  ],
  dependencies: [
    // 💧 A server-side Swift web framework.
    .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
    // 🗄 An ORM for SQL and NoSQL databases.
    .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
    // 🪶 Fluent driver for SQLite.
    .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
    // 🔵 Non-blocking, event-driven networking Swift. Used for, custom executors
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-url-routing.git", from: "0.6.2"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.6.0"),
  ],
  targets: [
    .target(
      name: "DatabaseClient",
      dependencies: [
        .target(name: "ManualDCore"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Fluent", package: "fluent"),
        .product(name: "Vapor", package: "vapor"),
      ]
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
