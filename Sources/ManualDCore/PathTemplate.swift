import Foundation

public struct PathTemplate: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let userID: User.ID
  public let revision: UUID
  public let configuration: Configuration
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID, userID: User.ID, revision: UUID, configuration: Configuration,
    createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.userID = userID
    self.revision = revision
    self.configuration = configuration
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public struct Configuration: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var name: String
    public var type: EquivalentLength.EffectiveLengthType
    public var steps: [Step]

    public init(name: String, type: EquivalentLength.EffectiveLengthType, steps: [Step]) {
      self.schemaVersion = 1
      self.name = name
      self.type = type
      self.steps = steps
    }

    /// Structural validation. The fitting service additionally checks catalog IDs and defaults.
    public func validate() throws {
      guard schemaVersion == 1 else { throw ConfigurationError.unsupportedVersion }
      guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        name.count <= 100
      else { throw ConfigurationError.invalidName }
      guard !steps.isEmpty, steps.count <= 50,
        Set(steps.map(\.id)).count == steps.count
      else { throw ConfigurationError.invalidSteps }
      for step in steps {
        guard step.group.supports(type) else { throw ConfigurationError.ineligibleGroup }
        guard !step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          step.title.count <= 100,
          !step.choices.isEmpty, step.choices.count <= 100,
          Set(step.choices.map(\.fittingID)).count == step.choices.count
        else { throw ConfigurationError.invalidSteps }
        for choice in step.choices {
          guard !choice.fittingID.rawValue.isEmpty, choice.fittingID.rawValue.count <= 100 else {
            throw ConfigurationError.invalidFitting
          }
          try choice.defaults?.validateTemplateDefault()
        }
      }
    }
  }

  public struct Step: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var group: TemplateFitting.Group
    public var behavior: Behavior
    public var allowsSkipping: Bool
    public var choices: [Choice]

    public init(
      id: UUID, title: String, group: TemplateFitting.Group, behavior: Behavior = .chooseOne,
      allowsSkipping: Bool = false, choices: [Choice]
    ) {
      self.id = id
      self.title = title
      self.group = group
      self.behavior = behavior
      self.allowsSkipping = allowsSkipping
      self.choices = choices
    }
  }

  public enum Behavior: String, CaseIterable, Codable, Sendable {
    case chooseOne
    case chooseMultiple
    case quantities
  }

  public struct Choice: Codable, Equatable, Sendable {
    public let fittingID: TemplateFitting.ID
    public var defaults: TemplateFitting.Inputs?

    public init(fittingID: TemplateFitting.ID, defaults: TemplateFitting.Inputs? = nil) {
      self.fittingID = fittingID
      self.defaults = defaults
    }
  }

  /// A value copy for a path draft, independent of the user's current template revision.
  public struct Snapshot: Codable, Equatable, Sendable {
    public let templateID: PathTemplate.ID
    public let revision: UUID
    public let configuration: Configuration

    public init(template: PathTemplate) {
      self.templateID = template.id
      self.revision = template.revision
      self.configuration = template.configuration
    }
  }

  public enum ConfigurationError: Error, Equatable, Sendable {
    case unsupportedVersion
    case invalidName
    case invalidSteps
    case ineligibleGroup
    case invalidFitting
    case invalidDefault
  }
}

extension TemplateFitting.Inputs {
  fileprivate func validateTemplateDefault() throws {
    func positive(_ value: Double?) throws {
      if let value, !value.isFinite || value <= 0 {
        throw PathTemplate.ConfigurationError.invalidDefault
      }
    }
    switch self {
    case .fixed:
      break
    case .dimensions(let numerator, let denominator):
      try positive(numerator)
      try positive(denominator)
    case .downstreamBranches(let count):
      if let count, count < 0 { throw PathTemplate.ConfigurationError.invalidDefault }
    case .sourceTable(let choices):
      guard choices.count <= 10,
        choices.allSatisfy({ choice in
          guard let choice else { return true }
          return !choice.isEmpty && choice.count <= 200
        })
      else { throw PathTemplate.ConfigurationError.invalidDefault }
    case .flexJunctionBox(let inputs):
      try positive(inputs.boxVelocityFpm)
      try positive(inputs.suppliedBend?.velocityFpm)
    }
  }
}
