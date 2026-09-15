import App
import DependenciesTestSupport
import Fluent
import Foundation
import ManualDCore
import SQLKit
import Testing
import Vapor

@testable import DatabaseClient

@Suite(.serialized, .dependencies { $0.uuid = .incrementing })
struct TrunkOrderMigrationTests {
  @Test func sqlite() async throws { try await checkMigration(postgres: false) }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["TRUNK_TEST_POSTGRES_HOST"] != nil))
  func postgres() async throws { try await checkMigration(postgres: true) }

  private func checkMigration(postgres: Bool) async throws {
    let app = try await Application.make(postgres ? .production : .testing)
    app.logger.logLevel = .critical
    do {
      try await configure(
        app,
        in: postgres
          ? .init(
            postgresHostname: ProcessInfo.processInfo.environment["TRUNK_TEST_POSTGRES_HOST"],
            postgresUsername: "template_test", postgresPassword: "local-test-password",
            postgresDatabase: "template_test", aggregateMetricsEnabled: "false") : .live())
      try await app.autoMigrate()
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "order@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let project = try await database.projects.create(user.id, .mock)
      let other = try await database.projects.create(
        user.id,
        .init(
          name: "Other project", streetAddress: "2 Main St", city: "Monroe", state: "OH",
          zipCode: "45050"))
      let sql = try #require(app.db as? any SQLDatabase)
      let migration = TrunkSize.AddPosition()
      try await migration.revert(on: app.db)
      let rows: [(UUID, UUID, String)] = [
        (UUID(40), project.id, "supply"), (UUID(20), project.id, "return"),
        (UUID(30), project.id, "supply"), (UUID(10), project.id, "return"),
        (UUID(50), other.id, "supply"),
      ]
      for (id, projectID, type) in rows {
        try await sql.raw(
          "INSERT INTO trunk (id, \(ident: "projectID"), type) VALUES (\(bind: id), \(bind: projectID), \(bind: type))"
        ).run()
      }
      try await migration.prepare(on: app.db)
      #expect(
        try await database.trunkSizes.fetch(project.id).map(\.id) == [
          UUID(30), UUID(40), UUID(10), UUID(20),
        ])
      #expect(try await TrunkModel.find(UUID(50), on: app.db)?.position == 0)
      for id in [30, 10] { #expect(try await TrunkModel.find(UUID(id), on: app.db)?.position == 0) }
      for id in [40, 20] { #expect(try await TrunkModel.find(UUID(id), on: app.db)?.position == 1) }
      let appended = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:]))
      #expect(
        try await database.trunkSizes.fetch(project.id).map(\.id) == [
          UUID(30), UUID(40), appended.id, UUID(10), UUID(20),
        ])
      try await database.trunkSizes.reorder(project.id, .supply, [appended.id, UUID(40), UUID(30)])
      #expect(
        try await database.projects.detail(project.id)?.trunks.map(\.id) == [
          appended.id, UUID(40), UUID(30), UUID(10), UUID(20),
        ])

      if postgres {
        // Each writer uses a separate connection, so assigning the next position must hold the project lock.
        let writers = try (0..<6).map { _ in
          DatabaseClient.live(
            database: try #require(
              app.databases.database(nil, logger: app.logger, on: app.eventLoopGroup.next())))
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
          for writer in writers {
            group.addTask {
              _ = try await writer.trunkSizes.create(
                .init(projectID: other.id, type: .supply, rooms: [:]))
            }
          }
          try await group.waitForAll()
        }
        let positions = try await TrunkModel.query(on: app.db)
          .filter(\.$project.$id == other.id).all().compactMap(\.position).sorted()
        #expect(positions == Array(0...6))
      }
      try await app.autoRevert()
      try await app.asyncShutdown()
    } catch {
      try? await app.autoRevert()
      try? await app.asyncShutdown()
      throw error
    }
  }
}
