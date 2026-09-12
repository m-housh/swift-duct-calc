import App
import Dependencies
import DependenciesTestSupport
import Fluent
import Foundation
import ManualDCore
import Testing
import Vapor

@testable import DatabaseClient

@Suite(.dependencies { $0.uuid = .incrementing })
struct DefaultPathTemplateTests {
  @Test func newAccountsOwnEditableDefaults() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database
      let templates = try await database.pathTemplates.fetch(user.id)
      #expect(Set(templates.map(\.configuration.name)) == ["Default supply", "Default return"])
      #expect(Set(templates.map(\.configuration.type)) == [.supply, .return])
      #expect(templates.allSatisfy { $0.userID == user.id })
      let supply = try #require(templates.first { $0.configuration.type == .supply })
      var configuration = supply.configuration
      configuration.name = "My local supply layout"
      configuration.steps[0].choices.removeLast()
      let updated = try await database.pathTemplates.update(
        user.id, supply.id, supply.revision, configuration)
      #expect(updated.configuration == configuration)
      #expect(updated.id == supply.id)
      try await database.pathTemplates.delete(user.id, supply.id)
      _ = try await database.users.get(user.id)
      #expect(
        try await database.pathTemplates.fetch(user.id).map(\.id)
          == templates.filter {
            $0.configuration.type == .return
          }.map(\.id))
    }
  }

  @Test func backfillPreservesExistingTemplatesAndDoesNotRecreateDeletedDefaultsOnRestart()
    async throws
  {
    let app = try await Application.make(.testing)
    do {
      try await configure(app, in: .live())
      try await app.autoMigrate()
      let database = DatabaseClient.live(database: app.db)
      var accounts: [(User.ID, [PathTemplate])] = []
      let existingTypes: [[EquivalentLength.EffectiveLengthType]] = [
        [], [.supply], [.return], [.supply, .return],
      ]
      for (index, types) in existingTypes.enumerated() {
        // Insert legacy accounts directly so signup provisioning cannot mask a backfill failure.
        let model = try User.Create(
          email: "legacy-\(index)@example.test", password: "super-secret",
          confirmPassword: "super-secret"
        ).toModel()
        try await model.save(on: app.db)
        let userID = try model.requireID()
        var existing: [PathTemplate] = []
        for type in types {
          var configuration = try #require(
            PathTemplate.defaultConfigurations().first { $0.type == type })
          configuration.name = "Custom \(type.rawValue) \(index)"
          existing.append(try await database.pathTemplates.create(userID, configuration))
        }
        accounts.append((userID, existing))
      }
      let migration = PathTemplate.AddDefaults()
      try await migration.prepare(on: app.db)
      var firstIDs = Set<PathTemplate.ID>()
      for (userID, existing) in accounts {
        let templates = try await database.pathTemplates.fetch(userID)
        #expect(templates.count == 2)
        #expect(Set(templates.map(\.configuration.type)) == [.supply, .return])
        firstIDs.formUnion(templates.map(\.id))
        for original in existing {
          #expect(try await database.pathTemplates.get(userID, original.id) == original)
        }
        for added in templates where !existing.contains(where: { $0.id == added.id }) {
          #expect(added.configuration.name == "Default \(added.configuration.type.rawValue)")
        }
      }
      try await migration.prepare(on: app.db)
      let secondIDs = try await PathTemplateModel.query(on: app.db).all().map { try $0.requireID() }
      #expect(Set(secondIDs) == firstIDs)
      let userID = accounts[0].0
      let deleted = try #require(try await database.pathTemplates.fetch(userID).first)
      try await database.pathTemplates.delete(userID, deleted.id)
      try await app.autoMigrate()
      #expect(try await database.pathTemplates.get(userID, deleted.id) == nil)
      #expect(try await database.pathTemplates.fetch(userID).count == 1)
      try await migration.revert(on: app.db)
      #expect(try await database.pathTemplates.fetch(userID).count == 1)
      try await app.asyncShutdown()
    } catch {
      try await app.asyncShutdown()
      throw error
    }
  }
}
