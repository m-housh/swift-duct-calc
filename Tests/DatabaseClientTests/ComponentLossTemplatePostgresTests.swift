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
struct ComponentLossTemplatePostgresTests {
  /// Uses a disposable database and widens the insertion window to expose overlapping replacements.
  @Test(.enabled(if: ProcessInfo.processInfo.environment["TEMPLATE_TEST_POSTGRES_HOST"] != nil))
  func concurrentReplacementsKeepOneTemplate() async throws {
    let app = try await Application.make(.production)
    app.logger.logLevel = .critical
    do {
      try await configure(
        app,
        in: .init(
          postgresHostname: ProcessInfo.processInfo.environment["TEMPLATE_TEST_POSTGRES_HOST"],
          postgresUsername: "template_test", postgresPassword: "local-test-password",
          postgresDatabase: "template_test", aggregateMetricsEnabled: "false"))
      let database = DatabaseClient.live(database: app.db)
      let sql = try #require(app.db as? any SQLDatabase)
      let user = try await database.users.create(
        .init(
          email: "templates@example.test", password: "super-secret", confirmPassword: "super-secret"
        ))
      let project = try await database.projects.create(user.id, .mock)
      let other = try await database.projects.create(
        user.id,
        .init(
          name: "Other project", streetAddress: "2 Test St", city: "Cincinnati", state: "OH",
          zipCode: "45202"))
      try await database.componentLosses.applyTemplate(other.id, .shared)
      let untouched = try await database.componentLosses.fetch(other.id)
      #expect(try await database.componentLosses.fetch(project.id).isEmpty)
      // Each event loop has its own pool; sharing one client would serialize on one connection.
      let writers = try (0..<9).map { _ in
        DatabaseClient.live(
          database: try #require(
            app.databases.database(
              nil, logger: app.logger, on: app.eventLoopGroup.next())))
      }

      try await sql.raw(
        """
        CREATE OR REPLACE FUNCTION pause_component_insert() RETURNS trigger AS $$
        BEGIN
          PERFORM pg_sleep(0.02);
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
        """
      ).run()
      try await sql.raw(
        """
        CREATE TRIGGER pause_component_insert BEFORE INSERT ON component_loss
        FOR EACH ROW EXECUTE FUNCTION pause_component_insert()
        """
      ).run()

      // Exercise both the initially empty project and replacement of existing losses.
      for _ in 0..<3 {
        try await withThrowingTaskGroup(of: Void.self) { group in
          for (index, writer) in writers.enumerated() {
            group.addTask {
              try await writer.componentLosses.applyTemplate(
                project.id, FrictionRateTemplate.allCases[index % 3])
            }
          }
          try await group.waitForAll()
        }
        let losses = try await database.componentLosses.fetch(project.id)
        #expect(
          FrictionRateTemplate.allCases.contains { template in
            let components = template.components(projectID: project.id)
            return losses.count == components.count
              && components.allSatisfy { component in
                losses.filter { $0.name == component.name && $0.value == component.value }.count
                  == 1
              }
          })
      }
      #expect(try await database.componentLosses.fetch(other.id) == untouched)
      try await sql.raw("DROP FUNCTION pause_component_insert() CASCADE").run()
      try await app.autoRevert()
      try await app.asyncShutdown()
    } catch {
      if let sql = app.db as? any SQLDatabase {
        try? await sql.raw("DROP FUNCTION IF EXISTS pause_component_insert() CASCADE").run()
      }
      try? await app.autoRevert()
      try? await app.asyncShutdown()
      throw error
    }
  }
}
