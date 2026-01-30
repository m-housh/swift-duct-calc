// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-manual-d",
  products: [
    .executable(name: "App", targets: ["App"]),
    .library(name: "AuthClient", targets: ["AuthClient"]),
    .library(name: "DatabaseClient", targets: ["DatabaseClient"]),
    .library(name: "EnvClient", targets: ["EnvClient"]),
    .library(name: "FileClient", targets: ["FileClient"]),
    .library(name: "HTMLSnapshotTesting", targets: ["HTMLSnapshotTesting"]),
    .library(name: "PdfClient", targets: ["PdfClient"]),
    .library(name: "ProjectClient", targets: ["ProjectClient"]),
    .library(name: "ManualDCore", targets: ["ManualDCore"]),
    .library(name: "ManualDClient", targets: ["ManualDClient"]),
    .library(name: "Styleguide", targets: ["Styleguide"]),
    .library(name: "ViewController", targets: ["ViewController"]),
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
    .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
    .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.12.0"),
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
    .package(url: "https://github.com/pointfreeco/swift-url-routing.git", from: "0.6.2"),
    .package(url: "https://github.com/pointfreeco/vapor-routing.git", from: "0.1.3"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.6.0"),
    .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.6.0"),
    .package(url: "https://github.com/elementary-swift/elementary-htmx.git", from: "0.5.0"),
    .package(url: "https://github.com/vapor-community/vapor-elementary.git", from: "0.1.0"),
  ],
  targets: [
    .executableTarget(
      name: "App",
      dependencies: [
        .target(name: "AuthClient"),
        .target(name: "DatabaseClient"),
        .target(name: "ViewController"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Fluent", package: "fluent"),
        .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "VaporElementary", package: "vapor-elementary"),
        .product(name: "VaporRouting", package: "vapor-routing"),
      ]
    ),
    .target(
      name: "AuthClient",
      dependencies: [
        .target(name: "DatabaseClient"),
        .target(name: "ManualDCore"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
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
    .testTarget(
      name: "DatabaseClientTests",
      dependencies: [
        .target(name: "App"),
        .target(name: "DatabaseClient"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
      ]
    ),
    .target(
      name: "EnvClient",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "FileClient",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Vapor", package: "vapor"),
      ]
    ),
    .target(
      name: "HTMLSnapshotTesting",
      dependencies: [
        .product(name: "Elementary", package: "elementary"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ]
    ),
    .target(
      name: "PdfClient",
      dependencies: [
        .target(name: "EnvClient"),
        .target(name: "FileClient"),
        .target(name: "ManualDCore"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Elementary", package: "elementary"),
      ]
    ),
    .testTarget(
      name: "PdfClientTests",
      dependencies: [
        .target(name: "HTMLSnapshotTesting"),
        .target(name: "PdfClient"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      resources: [
        .copy("__Snapshots__")
      ]
    ),
    .target(
      name: "ProjectClient",
      dependencies: [
        .target(name: "DatabaseClient"),
        .target(name: "ManualDClient"),
        .target(name: "PdfClient"),
        .product(name: "Vapor", package: "vapor"),
      ]
    ),
    .target(
      name: "ManualDCore",
      dependencies: [
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Fluent", package: "fluent"),
        .product(name: "URLRouting", package: "swift-url-routing"),
      ]
    ),
    .target(
      name: "ManualDClient",
      dependencies: [
        .target(name: "ManualDCore"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .target(
      name: "Styleguide",
      dependencies: [
        "ManualDCore",
        .product(name: "Elementary", package: "elementary"),
        .product(name: "ElementaryHTMX", package: "elementary-htmx"),
      ]
    ),
    .testTarget(
      name: "ManualDClientTests",
      dependencies: [
        "ManualDClient",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "ViewController",
      dependencies: [
        .target(name: "AuthClient"),
        .target(name: "DatabaseClient"),
        .target(name: "PdfClient"),
        .target(name: "ProjectClient"),
        .target(name: "ManualDClient"),
        .target(name: "ManualDCore"),
        .target(name: "Styleguide"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Elementary", package: "elementary"),
        .product(name: "ElementaryHTMX", package: "elementary-htmx"),
        .product(name: "Vapor", package: "vapor"),
      ]
    ),
    .testTarget(
      name: "ViewControllerTests",
      dependencies: [
        .target(name: "ViewController"),
        .target(name: "HTMLSnapshotTesting"),
      ],
      resources: [
        .copy("__Snapshots__")
      ]
    ),
  ]
)
