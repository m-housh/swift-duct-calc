import App
import DatabaseClient
import Dependencies
import Fluent
import FluentSQLiteDriver
import Foundation
import ManualDCore
import NIO
import Vapor

// Helper to create an in-memory database used for testing.
func withDatabase(
  setupDependencies: (inout DependencyValues) -> Void = { _ in },
  operation: () async throws -> Void
) async throws {
  let app = try await Application.make(.testing)
  do {
    try await configure(app)
    let database = app.db
    try await app.autoMigrate()

    try await withDependencies {
      $0.uuid = .incrementing
      $0.date = .init { Date() }
      $0.database = .live(database: database)
      setupDependencies(&$0)
    } operation: {
      try await operation()
    }

    try await app.autoRevert()
    try await app.asyncShutdown()

  } catch {
    try? await app.autoRevert()
    try await app.asyncShutdown()
    throw error
  }

}

/// Set's up the database and a test user for running tests that require a
/// a user.
func withTestUser(
  setupDependencies: (inout DependencyValues) -> Void = { _ in },
  operation: (User) async throws -> Void
) async throws {
  try await withDatabase(setupDependencies: setupDependencies) {
    @Dependency(\.database.users) var users
    let user = try await users.create(
      .init(email: "testy@example.com", password: "super-secret", confirmPassword: "super-secret")
    )
    try await operation(user)
  }
}
