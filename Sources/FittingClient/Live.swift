import Dependencies
import Foundation
import ManualDCore

extension FittingClient: DependencyKey {
  public static let liveValue: Self = .init(
    groups: { try Catalog.bundled.get().groups(for: $0) },
    fittings: { try Catalog.bundled.get().fittings($0) },
    artwork: { try Catalog.bundled.get().artwork($0) },
    evaluate: { try Catalog.bundled.get().evaluate($0) },
    resolveReference: { try Catalog.bundled.get().resolveReference($0) }
  )
}

/// Infrastructure failures; normal incomplete/unsupported inputs return structured results.
public enum FittingClientError: Error, Equatable, Sendable {
  case missingCatalog
  case invalidCatalog(String)
}
