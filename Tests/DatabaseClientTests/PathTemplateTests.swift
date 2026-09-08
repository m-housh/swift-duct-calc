import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

@Suite
struct PathTemplateTests {
  static var configuration: PathTemplate.Configuration {
    .init(
      name: "Usual supply", type: .supply,
      steps: [
        .init(
          id: UUID(10), title: "Connection", group: .supplyConnection,
          choices: [.init(fittingID: "1A"), .init(fittingID: "1B")]
        ),
        .init(
          id: UUID(11), title: "Elbows", group: .elbow, behavior: .quantities,
          allowsSkipping: true,
          choices: [
            .init(fittingID: "8A-4-or-5-piece", defaults: .sourceTable(choices: ["1"])),
            .init(fittingID: "8A-3-piece-45"),
          ]
        ),
      ]
    )
  }

  @Test
  func saveReorderAndDeletePreserveSnapshot() async throws {
    try await withTestUser { user in
      @Dependency(\.database.pathTemplates) var templates
      let created = try await templates.create(user.id, Self.configuration)
      let fetched = try await templates.get(user.id, created.id)
      #expect(fetched == created)
      let snapshot = PathTemplate.Snapshot(template: created)
      var edited = created.configuration
      edited.name = "Reordered supply"
      edited.steps.reverse()
      edited.steps[0].choices[0].defaults = .sourceTable(choices: [nil])
      let updated = try await templates.update(user.id, created.id, created.revision, edited)
      #expect(updated.configuration == edited)
      #expect(updated.revision != created.revision)
      #expect(updated.createdAt == created.createdAt)
      #expect(try await templates.get(user.id, created.id) == updated)
      #expect(snapshot.configuration == Self.configuration)
      #expect(
        try JSONDecoder().decode(
          PathTemplate.Snapshot.self, from: JSONEncoder().encode(snapshot)
        ) == snapshot
      )
      try await templates.delete(user.id, created.id)
      #expect(try await templates.fetch(user.id).isEmpty)
      #expect(snapshot.configuration.steps.count == 2)
    }
  }

  @Test
  func staleUpdateDoesNotOverwriteNewerConfiguration() async throws {
    try await withTestUser { user in
      @Dependency(\.database.pathTemplates) var templates
      let created = try await templates.create(user.id, Self.configuration)
      var edited = created.configuration
      edited.name = "Newer changes"
      let updated = try await templates.update(user.id, created.id, created.revision, edited)
      await #expect(throws: PathTemplateConflictError.self) {
        try await templates.update(user.id, created.id, created.revision, Self.configuration)
      }
      #expect(try await templates.get(user.id, created.id) == updated)
    }
  }

  @Test
  func anotherUserCannotReadOrMutateTemplate() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database
      let other = try await database.users.create(
        .init(email: "other@example.com", password: "super-secret", confirmPassword: "super-secret")
      )
      let templates = database.pathTemplates
      let created = try await templates.create(user.id, Self.configuration)
      #expect(try await templates.get(other.id, created.id) == nil)
      #expect(try await templates.fetch(other.id).isEmpty)
      await #expect(throws: NotFoundError.self) {
        try await templates.update(other.id, created.id, created.revision, Self.configuration)
      }
      await #expect(throws: NotFoundError.self) {
        try await templates.delete(other.id, created.id)
      }
      #expect(try await templates.get(user.id, created.id) == created)
    }
  }

  @Test
  func concurrentEditorsCannotBothOverwriteTheSameRevision() async throws {
    try await withTestUser { user in
      @Dependency(\.database.pathTemplates) var templates
      let created = try await templates.create(user.id, Self.configuration)
      let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
        for name in ["Editor one", "Editor two"] {
          group.addTask { [templates] in
            var configuration = created.configuration
            configuration.name = name
            do {
              _ = try await templates.update(user.id, created.id, created.revision, configuration)
              return true
            } catch is PathTemplateConflictError {
              return false
            } catch {
              Issue.record(error)
              return false
            }
          }
        }
        var results = [Bool]()
        for await result in group { results.append(result) }
        return results
      }
      #expect(results.filter { $0 }.count == 1)
    }
  }

  @Test
  func invalidConfigurationIsNotSaved() async throws {
    try await withTestUser { user in
      @Dependency(\.database.pathTemplates) var templates
      var invalid = Self.configuration
      invalid.type = .return
      await #expect(throws: PathTemplate.ConfigurationError.ineligibleGroup) {
        try await templates.create(user.id, invalid)
      }
      let saved = try await templates.fetch(user.id)
      #expect(saved.isEmpty)
    }
  }

  @Test
  func everyEligibleGroupCanBeConfigured() throws {
    for type in EquivalentLength.EffectiveLengthType.allCases {
      let steps = TemplateFitting.Group.allCases.filter { $0.supports(type) }.map { group in
        PathTemplate.Step(
          id: UUID(), title: "Group \(group.rawValue)", group: group,
          choices: [.init(fittingID: .init(rawValue: "catalog-case-\(group.rawValue)"))]
        )
      }
      try PathTemplate.Configuration(name: "Custom", type: type, steps: steps).validate()
      #expect(steps.count == (type == .supply ? 8 : 7))
    }
  }

  @Test
  func structuralValidationRejectsMalformedTemplates() {
    var invalid = Self.configuration
    invalid.steps.append(invalid.steps[0])
    #expect(throws: PathTemplate.ConfigurationError.invalidSteps) { try invalid.validate() }
    invalid = Self.configuration
    invalid.steps[0].choices.append(invalid.steps[0].choices[0])
    #expect(throws: PathTemplate.ConfigurationError.invalidSteps) { try invalid.validate() }
    invalid = Self.configuration
    invalid.steps[0].choices = []
    #expect(throws: PathTemplate.ConfigurationError.invalidSteps) { try invalid.validate() }
    invalid = Self.configuration
    invalid.name = " \n "
    #expect(throws: PathTemplate.ConfigurationError.invalidName) { try invalid.validate() }
    invalid = Self.configuration
    invalid.steps[0].choices[0].defaults = .dimensions(numeratorInches: 10, denominatorInches: 0)
    #expect(throws: PathTemplate.ConfigurationError.invalidDefault) { try invalid.validate() }
  }

  @Test
  func unansweredCountRemainsDistinctFromZero() throws {
    let unanswered = TemplateFitting.Inputs.downstreamBranches(nil)
    let zero = TemplateFitting.Inputs.downstreamBranches(0)
    #expect(unanswered != zero)
    #expect(
      try JSONDecoder().decode(TemplateFitting.Inputs.self, from: JSONEncoder().encode(unanswered))
        == unanswered
    )
    #expect(
      try JSONDecoder().decode(TemplateFitting.Inputs.self, from: JSONEncoder().encode(zero)) == zero
    )
  }
}
