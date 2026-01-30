import Dependencies
import DependenciesTestSupport
import Fluent
import FluentSQLiteDriver
import ManualDCore
import Testing
import Vapor

@testable import DatabaseClient

@Suite
struct ProjectTests {

  @Test
  func sanity() {
    #expect(Bool(true))
  }

  // @Test
  // func createProject() {
  //   try await withDatabase(migrations: Project.Migrate()) {
  //     $0.database.projects = .live(database: $1)
  //   } operation: {
  //     @Dependency(\.database.projects) var projects
  //
  //     let project = try await projects.c
  //   }
  // }
}
