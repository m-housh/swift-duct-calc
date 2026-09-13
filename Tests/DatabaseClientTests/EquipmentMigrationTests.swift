import Dependencies
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Foundation
import ManualDCore
import SQLKit
import Testing
import Vapor

@testable import DatabaseClient

struct EquipmentMigrationTests {
  @Test func sqlite() async throws { try await migration(postgres: false) }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["EQUIPMENT_TEST_POSTGRES_HOST"] != nil))
  func postgres() async throws { try await migration(postgres: true) }

  private func migration(postgres: Bool) async throws {
    let app = try await Application.make(.testing)
    app.logger.logLevel = .critical
    if postgres {
      app.databases.use(
        .postgres(
          configuration: .init(
            hostname: ProcessInfo.processInfo.environment["EQUIPMENT_TEST_POSTGRES_HOST"]!,
            username: "template_test", password: "local-test-password", database: "template_test",
            tls: .disable)),
        as: .psql)
    } else {
      app.databases.use(.sqlite(.memory), as: .sqlite)
    }
    do {
      try await User.Migrate().prepare(on: app.db)
      try await Project.Migrate().prepare(on: app.db)
      try await EquipmentInfo.Migrate().prepare(on: app.db)
      let sql = try #require(app.db as? any SQLDatabase)
      let userID = UUID()
      let projectID = UUID()
      let equipmentID = UUID()
      try await sql.raw(
        """
        INSERT INTO "user" ("id", "email", "password_hash")
        VALUES (\(bind: userID), 'migration@example.test', 'unused')
        """
      ).run()
      try await sql.raw(
        """
        INSERT INTO "project" ("id", "name", "streetAddress", "city", "state", "zipCode", "userID")
        VALUES (\(bind: projectID), 'Migration', '1 Main', 'Monroe', 'OH', '45050', \(bind: userID))
        """
      ).run()
      let original = EquipmentModel(
        id: equipmentID, staticPressure: 0.5, heatingCFM: 900,
        coolingCFM: 1200, projectID: projectID)
      try await original.save(on: app.db)
      let before = try original.toDTO()
      let migration = EquipmentInfo.AllowMissingAirflow()
      try await migration.prepare(on: app.db)
      let client = DatabaseClient.Equipment.live(database: app.db)
      #expect(try await client.get(equipmentID) == before)
      await #expect(throws: (any Error).self) {
        try await client.create(.init(projectID: projectID, heatingCFM: 1000))
      }
      // Reverse and reapply with real records, including PostgreSQL constraint names.
      try await migration.revert(on: app.db)
      #expect(try await client.get(equipmentID) == before)
      try await migration.prepare(on: app.db)
      try await client.delete(equipmentID)
      let draft = try await client.create(.init(projectID: projectID, coolingCFM: 1200))
      #expect(draft.heatingCFM == nil && draft.coolingCFM == 1200)
      await #expect(throws: (any Error).self) { try await migration.revert(on: app.db) }
      #expect(try await client.get(draft.id) == draft)
      _ = try await client.update(draft.id, .init(heatingCFM: 900))
      try await sql.raw(
        "DELETE FROM \(ident: ProjectModel.schema) WHERE \(ident: "id") = \(bind: projectID)"
      ).run()
      #expect(try await client.get(draft.id) == nil)
      try await migration.revert(on: app.db)
      try await EquipmentInfo.Migrate().revert(on: app.db)
      try await Project.Migrate().revert(on: app.db)
      try await User.Migrate().revert(on: app.db)
      try await app.asyncShutdown()
    } catch {
      try await app.asyncShutdown()
      throw error
    }
  }
}
