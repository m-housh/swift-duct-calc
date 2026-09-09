import Dependencies
import FittingClient
import Foundation
import ManualDCore
import Testing

@Suite
struct PathTemplateTransferTests {
  @Test
  func portableRoundTripKeepsConfigurationAndCreatesNewSectionIDs() async throws {
    try await withDependencies {
      $0.uuid = .incrementing
    } operation: {
      for original in PathTemplate.starterConfigurations() {
        let file = PathTemplate.Transfer(configuration: original)
        let encoded = try JSONEncoder().encode(file)
        let json = String(decoding: encoded, as: UTF8.self)
        for key in ["id", "userID", "projectID", "revision", "createdAt", "updatedAt"] {
          #expect(!json.contains("\"\(key)\":"))
        }
        let decoded = try JSONDecoder().decode(PathTemplate.Transfer.self, from: encoded)
        let imported = try decoded.configuration()
        #expect(Set(imported.steps.map(\.id)).isDisjoint(with: original.steps.map(\.id)))
        #expect(PathTemplate.Transfer(configuration: imported) == file)
        try await TemplateFittingClient.liveValue.validateTemplate(imported)
      }
    }
  }

  @Test
  func requiredUnsupportedSectionsAreRejectedButOptionalAndMixedSectionsWork() async throws {
    var config = PathTemplate.Configuration(
      name: "Offsets", type: .supply,
      steps: [
        .init(id: UUID(), title: "Offset", group: .elbow, choices: [.init(fittingID: "8O")])
      ])
    await #expect(
      throws: TemplateFittingClient.TemplateValidationError.unusableSection(section: "Offset")
    ) {
      try await TemplateFittingClient.liveValue.validateTemplate(config)
    }
    config.steps[0].allowsSkipping = true
    try await TemplateFittingClient.liveValue.validateTemplate(config)
    config.steps[0].allowsSkipping = false
    config.steps[0].choices.append(.init(fittingID: "8A-smooth"))
    try await TemplateFittingClient.liveValue.validateTemplate(config)
  }

  @Test
  func unknownVersionAndMalformedFileCannotBeImported() throws {
    try withDependencies {
      $0.uuid = .incrementing
    } operation: {
      let file = PathTemplate.Transfer(configuration: PathTemplate.starterConfigurations()[0])
      var json = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(file)) as? [String: Any])
      json["version"] = 99
      let unsupported = try JSONDecoder().decode(
        PathTemplate.Transfer.self, from: JSONSerialization.data(withJSONObject: json))
      #expect(throws: PathTemplate.ConfigurationError.unsupportedVersion) {
        try unsupported.configuration()
      }
      json.removeValue(forKey: "steps")
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(
          PathTemplate.Transfer.self, from: JSONSerialization.data(withJSONObject: json))
      }
    }
  }

  @Test
  func importedMissingFittingsAndUnsupportedDefaultsAreRejected() async throws {
    try await withDependencies {
      $0.uuid = .incrementing
    } operation: {
      var original = PathTemplate.starterConfigurations()[0]
      original.steps[0].choices = [.init(fittingID: "missing-fitting")]
      let missing = try PathTemplate.Transfer(configuration: original).configuration()
      await #expect(
        throws: TemplateFittingClient.TemplateValidationError.invalidFitting(
          section: missing.steps[0].title, fittingID: "missing-fitting")
      ) {
        try await TemplateFittingClient.liveValue.validateTemplate(missing)
      }
      original.steps[0].choices = [.init(fittingID: "1A", defaults: .downstreamBranches(0))]
      let invalid = try PathTemplate.Transfer(configuration: original).configuration()
      await #expect(
        throws: TemplateFittingClient.TemplateValidationError.invalidDefault(
          section: invalid.steps[0].title, fittingID: "1A")
      ) {
        try await TemplateFittingClient.liveValue.validateTemplate(invalid)
      }
    }
  }
}
