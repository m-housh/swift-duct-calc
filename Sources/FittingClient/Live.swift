import Dependencies
import Foundation
import ManualDCore

extension FittingClient: DependencyKey {
  public static let liveValue: Self = {
    // Resolve the packaged catalog once when assembling the live dependency.
    // Capture failures too, so each operation reports the same infrastructure error.
    let catalog = Result {
      guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
        throw FittingClientError.missingCatalog
      }
      return try Catalog(data: Data(contentsOf: url))
    }

    return .init(
      groups: { try catalog.get().groups(for: $0) },
      fittings: { try catalog.get().fittings($0) },
      artwork: { try catalog.get().artwork($0) },
      evaluate: { try catalog.get().evaluate($0) },
      resolveReference: { try catalog.get().resolveReference($0) }
    )
  }()
}

/// Infrastructure failures; normal incomplete/unsupported inputs return structured results.
public enum FittingClientError: Error, Equatable, Sendable {
  case missingCatalog
  case invalidCatalog(String)
}
