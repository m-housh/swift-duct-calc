import Dependencies
import DependenciesMacros
import ManualDCore

extension DependencyValues {
  public var templateFittingClient: TemplateFittingClient {
    get { self[TemplateFittingClient.self] }
    set { self[TemplateFittingClient.self] = newValue }
  }
}

@DependencyClient
public struct TemplateFittingClient: Sendable {
  public var fittings:
    @Sendable (EquivalentLength.EffectiveLengthType) async throws -> [TemplateFitting.Definition]
  public var evaluate:
    @Sendable (TemplateFitting.EvaluationRequest) async throws -> TemplateFitting.Evaluation
  public var validateTemplate: @Sendable (PathTemplate.Configuration) async throws -> Void
}

extension TemplateFittingClient: DependencyKey {
  public static let testValue = Self()
  public static let liveValue = live(
    browse: { try TemplateCatalog.runtime.get().fittings($0) },
    evaluate: { try TemplateCatalog.runtime.get().evaluate($0) })

  public static func live(using client: FittingClient) -> Self {
    live(browse: client.fittings, evaluate: client.evaluate)
  }

  private static func live(
    browse: @escaping @Sendable (Fitting.BrowseRequest) async throws -> [Fitting.Definition],
    evaluate: @escaping @Sendable (Fitting.EvaluationRequest) async throws -> Fitting.Evaluation
  ) -> Self {
    Self(
      fittings: { type in
        try TemplateCatalog.shared.get().entries.filter { $0.group.supports(type) }.map(
          \.definition)
      },
      evaluate: { request in
        try await TemplateCatalog.shared.get().evaluate(request, browse: browse, evaluate: evaluate)
      },
      validateTemplate: { configuration in
        try configuration.validate()
        let entries = try TemplateCatalog.shared.get().entries
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
}

extension TemplateFittingClient {
  /// TemplateCatalog validation includes the section and choice so every caller can explain failures.
  public enum TemplateValidationError: Error, Equatable, Sendable {
    case invalidFitting(section: String, fittingID: TemplateFitting.ID)
    case invalidDefault(section: String, fittingID: TemplateFitting.ID)

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
