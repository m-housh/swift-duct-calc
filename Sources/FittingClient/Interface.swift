import Dependencies
import DependenciesMacros
import ManualDCore

extension DependencyValues {
  public var fittingClient: FittingClient {
    get { self[FittingClient.self] }
    set { self[FittingClient.self] = newValue }
  }
}

@DependencyClient
public struct FittingClient: Sendable {
  public var fittings:
    @Sendable (EquivalentLength.EffectiveLengthType) async throws -> [Fitting.Definition]
  public var evaluate: @Sendable (Fitting.EvaluationRequest) async throws -> Fitting.Evaluation
  public var validateTemplate: @Sendable (PathTemplate.Configuration) async throws -> Void
}

extension FittingClient: DependencyKey {
  public static let testValue = Self()
  public static let liveValue = Self(
    fittings: { type in
      try Catalog.shared.get().entries.filter { $0.group.supports(type) }.map(\.definition)
    },
    evaluate: { request in
      try Catalog.shared.get().evaluate(request)
    },
    validateTemplate: { configuration in
      try configuration.validate()
      let entries = try Catalog.shared.get().entries
      for step in configuration.steps {
        for choice in step.choices {
          guard let fitting = entries.first(where: { $0.id == choice.fittingID }),
            fitting.group == step.group, fitting.group.supports(configuration.type)
          else {
            throw TemplateValidationError.invalidFitting(
              section: step.title, fittingID: choice.fittingID)
          }
          if let defaults = choice.defaults, !fitting.definition.requirements.accepts(defaults) {
            throw TemplateValidationError.invalidDefault(
              section: step.title, fittingID: choice.fittingID)
          }
        }
      }
    }
  )
}

extension FittingClient {
  /// Catalog validation includes the section and choice so every caller can explain failures.
  public enum TemplateValidationError: Error, Equatable, Sendable {
    case invalidFitting(section: String, fittingID: Fitting.ID)
    case invalidDefault(section: String, fittingID: Fitting.ID)

    public var message: String {
      switch self {
      case .invalidFitting(let section, let id):
        return "\(section): fitting \(id.rawValue) is missing or incompatible."
      case .invalidDefault(let section, let id):
        return "\(section): defaults for \(id.rawValue) are no longer supported."
      }
    }
  }
}
