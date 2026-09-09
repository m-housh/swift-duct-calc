import Dependencies
import FileClient
import Foundation
import ManualDCore

extension FittingClient {
  /// Load the packaged catalog once, then share it across the client operations.
  public static func live(reviewCatalogPath: String? = nil) async throws -> Self {
    @Dependency(\.fileClient) var fileClient
    guard let referenceURL = Bundle.module.url(forResource: "reference", withExtension: "json")
    else {
      throw FittingClientError.missingCatalog
    }
    let referenceData = try await fileClient.readFile(referenceURL.path)
    func reference(for catalog: Catalog) throws -> FittingReference {
      try FittingReference(
        data: referenceData,
        pathGroups: Dictionary(
          uniqueKeysWithValues:
            Fitting.PathType.allCases.map { path in
              (path, catalog.groups(for: path).map { $0.id.rawValue })
            }))
    }
    if let reviewCatalogPath {
      let store = try CatalogReviewStore(path: reviewCatalogPath)
      let referenceCatalog = try reference(for: await store.catalog())
      return .init(
        reference: { referenceCatalog },
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
    guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
      throw FittingClientError.missingCatalog
    }
    let data = try await fileClient.readFile(url.path)
    let catalog = try Catalog(data: data)

    let referenceCatalog = try reference(for: catalog)
    return .init(
      reference: { referenceCatalog },
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
