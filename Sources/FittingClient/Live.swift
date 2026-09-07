import Dependencies
import FileClient
import Foundation
import ManualDCore

extension FittingClient {
  /// Load the packaged catalog once, then share it across the client operations.
  public static func live(reviewCatalogPath: String? = nil) async throws -> Self {
    if let reviewCatalogPath {
      let store = try CatalogReviewStore(path: reviewCatalogPath)
      return .init(
        catalogReviewEnabled: { true },
        catalogReview: { try await store.review() },
        saveCatalogReview: { try await store.save($0) },
        groups: { try await store.catalog().groups(for: $0) },
        fittings: { try await store.catalog().fittings($0) },
        artwork: { try await store.catalog().artwork($0) },
        evaluate: { try await store.catalog().evaluate($0) },
        resolveReference: { try await store.catalog().resolveReference($0) }
      )
    }
    @Dependency(\.fileClient) var fileClient

    guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
      throw FittingClientError.missingCatalog
    }
    let data = try await fileClient.readFile(url.path)
    let catalog = try Catalog(data: data)

    return .init(
      catalogReviewEnabled: { false },
      catalogReview: { throw CatalogReviewError.disabled },
      saveCatalogReview: { _ in throw CatalogReviewError.disabled },
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
