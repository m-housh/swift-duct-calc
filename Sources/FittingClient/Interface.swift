import Dependencies
import DependenciesMacros
import ManualDCore

extension DependencyValues {
  public var fittingClient: FittingClient {
    get { self[FittingClient.self] }
    set { self[FittingClient.self] = newValue }
  }
}

/// Project-independent fitting catalog, source identity, artwork and equivalent-length rules.
@DependencyClient
public struct FittingClient: Sendable {
  public var catalogReviewEnabled: @Sendable () -> Bool = { false }
  public var catalogReview: @Sendable () async throws -> Fitting.CatalogReview
  public var saveCatalogReview:
    @Sendable (Fitting.CatalogReviewSave) async throws -> Fitting.CatalogReview
  public var groups: @Sendable (Fitting.PathType) async throws -> [Fitting.Group]
  public var fittings: @Sendable (Fitting.BrowseRequest) async throws -> [Fitting.Definition]
  public var artwork: @Sendable (Fitting.ArtworkRequest) async throws -> Fitting.ArtworkResolution
  /// Group 6 return junctions resolve to paired branch/trunk contributions for path assembly.
  public var evaluate: @Sendable (Fitting.EvaluationRequest) async throws -> Fitting.Evaluation
  public var resolveReference:
    @Sendable (Fitting.ReferenceRequest) async throws -> Fitting.ReferenceMatch
}

extension FittingClient: TestDependencyKey {
  public static let testValue = Self()
}
