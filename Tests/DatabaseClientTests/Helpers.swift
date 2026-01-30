import App
import DatabaseClient
import Dependencies
import Fluent
import FluentSQLiteDriver
import Foundation
import NIO
import Vapor

// Helper to create an in-memory database for testing.
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
