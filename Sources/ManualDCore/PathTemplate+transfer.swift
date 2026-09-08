import Dependencies
import Foundation

extension PathTemplate {
  /// Portable configuration only. Account, project, revision and section IDs are excluded.
  public struct Transfer: Codable, Equatable, Sendable {
    public let format: String
    public let version: Int
    public let name: String
    public let type: EquivalentLength.EffectiveLengthType
    public let steps: [Section]

    public struct Section: Codable, Equatable, Sendable {
      public let title: String
      public let group: Fitting.Group
      public let behavior: Behavior
      public let allowsSkipping: Bool
      public let choices: [Choice]
    }

    public init(configuration: Configuration) {
      format = "duct-calc-path-template"
      version = 1
      name = configuration.name
      type = configuration.type
      steps = configuration.steps.map {
        Section(
          title: $0.title, group: $0.group, behavior: $0.behavior,
          allowsSkipping: $0.allowsSkipping, choices: $0.choices)
      }
    }

    public func configuration() throws -> Configuration {
      guard format == "duct-calc-path-template", version == 1 else {
        throw ConfigurationError.unsupportedVersion
      }
      @Dependency(\.uuid) var uuid
      let configuration = Configuration(
        name: name, type: type,
        steps: steps.map {
          Step(
            id: uuid(), title: $0.title, group: $0.group, behavior: $0.behavior,
            allowsSkipping: $0.allowsSkipping, choices: $0.choices)
        })
      try configuration.validate()
      return configuration
    }
  }
}
