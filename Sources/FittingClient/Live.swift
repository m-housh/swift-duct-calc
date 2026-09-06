import Dependencies
import FileClient
import Foundation
import ManualDCore

extension FittingClient {
  /// Load the packaged catalog once, then share it across the client operations.
  public static func live() async throws -> Self {
    @Dependency(\.fileClient) var fileClient

    guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
      throw FittingClientError.missingCatalog
    }
    let data = try await fileClient.readFile(url.path)
    let catalog = try Catalog(data: data)

    return .init(
      groups: { catalog.groups(for: $0) },
      fittings: { catalog.fittings($0) },
      artwork: { catalog.artwork($0) },
      evaluate: { catalog.evaluate($0) },
      resolveReference: { catalog.resolveReference($0) }
    )
  }
}

/// Infrastructure failures; normal incomplete/unsupported inputs return structured results.
public enum FittingClientError: Error, Equatable, Sendable {
  case missingCatalog
  case invalidCatalog(String)
}
