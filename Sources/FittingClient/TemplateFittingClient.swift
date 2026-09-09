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
  public static let liveValue: Self = {
    var client = FittingClient()
    client.groups = { try TemplateCatalog.runtime.get().groups(for: $0) }
    client.fittings = { try TemplateCatalog.runtime.get().fittings($0) }
    client.artwork = { try TemplateCatalog.runtime.get().artwork($0) }
    client.evaluate = { try TemplateCatalog.runtime.get().evaluate($0) }
    return live(using: client)
  }()

  public static func live(using client: FittingClient) -> Self {
    @Sendable func definitions(_ type: Fitting.PathType) async throws -> [Fitting.Definition] {
      var result: [Fitting.Definition] = []
      for group in try await client.groups(type) {
        result += try await client.fittings(.init(pathType: type, groupID: group.id))
      }
      return result
    }
    return Self(
      fittings: { type in
        var result: [TemplateFitting.Definition] = []
        for fitting in try await definitions(type) {
          var artworkPath: String?
          if case .available(let artwork) = try await client.artwork(.init(fittingID: fitting.id)) {
            artworkPath = artwork.versionedPath
          }
          result.append(
            .init(
              id: .init(rawValue: fitting.id.rawValue),
              group: TemplateFitting.Group(rawValue: fitting.groupID.rawValue)!,
              sourceCode: fitting.sourceCode?.rawValue, name: fitting.name,
              artworkPath: artworkPath, sourcePages: [], notes: fitting.conditions.notes,
              requirements: TemplateCatalog.requirements(fitting.inputRequirement)))
        }
        return result
      },
      evaluate: { request in
        guard
          let definition = try await definitions(request.type).first(where: {
            $0.id.rawValue == request.fittingID.rawValue
          }), TemplateCatalog.requirements(definition.inputRequirement).accepts(request.inputs),
          let inputs = TemplateCatalog.runtimeInputs(
            request.inputs, requirement: definition.inputRequirement)
        else { return .unresolved("Choose supported source conditions for this fitting.") }
        switch try await client.evaluate(
          .init(pathType: request.type, fittingID: definition.id, inputs: inputs))
        {
        case .resolved(let calculation):
          return .resolved(
            .init(
              fittingID: request.fittingID, inputs: request.inputs,
              equivalentLengthFeet: calculation.equivalentLengthFeet,
              ruleRevision: calculation.ruleRevision, catalogCalculation: calculation))
        default:
          return .unresolved(
            "No supported calculation covers these inputs. Check the source conditions.")
        }
      },
      validateTemplate: { configuration in
        try configuration.validate()
        let entries = try await definitions(configuration.type)
        for step in configuration.steps {
          var supported = false
          for choice in step.choices {
            guard
              let fitting = entries.first(where: { $0.id.rawValue == choice.fittingID.rawValue }),
              fitting.groupID.rawValue == step.group.rawValue
            else {
              throw TemplateValidationError.invalidFitting(
                section: step.title, fittingID: choice.fittingID)
            }
            let requirements = TemplateCatalog.requirements(fitting.inputRequirement)
            supported = supported || requirements.emptyInputs != nil
            if let defaults = choice.defaults, !requirements.accepts(defaults) {
              throw TemplateValidationError.invalidDefault(
                section: step.title, fittingID: choice.fittingID)
            }
          }
          if !step.allowsSkipping && !supported {
            throw TemplateValidationError.unusableSection(section: step.title)
          }
        }
      }
    )
  }
}

extension TemplateFittingClient {
  /// Template validation includes the section and choice so every caller can explain failures.
  public enum TemplateValidationError: Error, Equatable, Sendable {
    case unusableSection(section: String)
    case invalidFitting(section: String, fittingID: TemplateFitting.ID)
    case invalidDefault(section: String, fittingID: TemplateFitting.ID)

    public var message: String {
      switch self {
      case .unusableSection(let section):
        return
          "\(section): add a fitting with supported guided inputs or allow skipping this section."
      case .invalidFitting(let section, let id):
        return "\(section): fitting \(id.rawValue) is missing or incompatible."
      case .invalidDefault(let section, let id):
        return "\(section): defaults for \(id.rawValue) are no longer supported."
      }
    }
  }
}
