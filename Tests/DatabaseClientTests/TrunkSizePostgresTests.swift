import App
import DependenciesTestSupport
import Fluent
import Foundation
import ManualDCore
import SQLKit
import Testing
import Vapor

@testable import DatabaseClient

@Suite(.dependencies { $0.uuid = .incrementing })
struct TrunkSizePostgresTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["TRUNK_TEST_POSTGRES_HOST"] != nil))
  func concurrentWritesRejectDuplicateNames() async throws {
    let app = try await Application.make(.production)
    app.logger.logLevel = .critical
    do {
      try await configure(
        app,
        in: .init(
          postgresHostname: ProcessInfo.processInfo.environment["TRUNK_TEST_POSTGRES_HOST"],
          postgresUsername: "template_test", postgresPassword: "local-test-password",
          postgresDatabase: "template_test", aggregateMetricsEnabled: "false"))
      let database = DatabaseClient.live(database: app.db)
      let sql = try #require(app.db as? any SQLDatabase)
      let user = try await database.users.create(
        .init(
          email: "trunks@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let project = try await database.projects.create(user.id, .mock)
      try await sql.raw(
        """
        UPDATE project SET "updatedAt" = '2000-01-01T00:00:00Z' WHERE id = \(bind: project.id)
        """
      ).run()
      let originalProject = try #require(try await database.projects.get(project.id))
      let room = try await database.rooms.create(
        project.id,
        .init(name: "Living room", heatingLoad: 1000, coolingTotal: 800, registerCount: 2))
      // Separate event-loop pools allow transactions to overlap on different connections.
      let writers = try (0..<6).map { _ in
        DatabaseClient.live(
          database: try #require(
            app.databases.database(nil, logger: app.logger, on: app.eventLoopGroup.next())))
      }
      // Delay the write after validation to expose the original check-then-save race.
      try await sql.raw(
        """
        CREATE FUNCTION pause_trunk_write() RETURNS trigger AS $$
        BEGIN
          PERFORM pg_sleep(0.1);
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
        """
      ).run()
      try await sql.raw(
        """
        CREATE TRIGGER pause_trunk_write BEFORE INSERT OR UPDATE ON trunk
        FOR EACH ROW EXECUTE FUNCTION pause_trunk_write()
        """
      ).run()

      // Cover create/create, rename/rename, and create/rename races.
      for renameCount in [0, writers.count, writers.count / 2] {
        var originals = [TrunkSize]()
        for index in 0..<renameCount {
          originals.append(
            try await database.trunkSizes.create(
              .init(
                projectID: project.id, type: .return, rooms: [room.id: [1]], height: 8,
                name: "Original \(index)")))
        }
        let trunksToRename = originals
        let results = try await withThrowingTaskGroup(of: TrunkSize?.self) { group in
          for (index, writer) in writers.enumerated() {
            group.addTask {
              let name = index.isMultiple(of: 2) ? "Main trunk" : "  MAIN TRUNK\n"
              do {
                if index < trunksToRename.count {
                  return try await writer.trunkSizes.update(
                    trunksToRename[index].id,
                    .init(type: .supply, rooms: [room.id: [2]], height: 12, name: name))
                }
                return try await writer.trunkSizes.create(
                  .init(
                    projectID: project.id, type: .supply, rooms: [room.id: [2]], height: 12,
                    name: name))
              } catch is ValidationError {
                return nil
              }
            }
          }
          var results = [TrunkSize]()
          for try await result in group {
            if let result { results.append(result) }
          }
          return results
        }
        #expect(results.count == 1)
        #expect(try await database.projects.get(project.id) == originalProject)
        if let winner = results.first {
          _ = try await database.trunkSizes.update(winner.id, .init(name: winner.name))
          #expect(try await database.projects.get(project.id) == originalProject)
        }
        let saved = try await database.trunkSizes.fetch(project.id)
        #expect(
          saved.filter {
            $0.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "main trunk"
          }.count == 1)
        // Losing renames must leave dimensions, type, and room assignments untouched.
        for original in originals where !results.contains(where: { $0.id == original.id }) {
          #expect(try await database.trunkSizes.get(original.id) == original)
        }
        let createdCount = results.filter { result in
          !originals.contains(where: { $0.id == result.id })
        }.count
        #expect(saved.count == originals.count + createdCount)
        for trunk in saved { try await database.trunkSizes.delete(trunk.id) }
      }

      try await sql.raw("DROP FUNCTION pause_trunk_write() CASCADE").run()
      try await app.autoRevert()
      try await app.asyncShutdown()
    } catch {
      if let sql = app.db as? any SQLDatabase {
        try? await sql.raw("DROP FUNCTION IF EXISTS pause_trunk_write() CASCADE").run()
      }
      try? await app.autoRevert()
      try? await app.asyncShutdown()
      throw error
    }
  }
}
