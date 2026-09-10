import DatabaseClient
import EnvVars
import Foundation
import ManualDCore
import Testing
import Vapor

@testable import App

@Suite
struct AdminMetricsPostgresTests {
  /// Opt in only with a disposable PostgreSQL database; all migrations are reverted afterward.
  @Test(.enabled(if: ProcessInfo.processInfo.environment["METRICS_TEST_POSTGRES_HOST"] != nil))
  func concurrentPostgresFlushes() async throws {
    let app = try await Application.make(.production)
    app.logger.logLevel = .critical
    do {
      try await configure(
        app,
        in: .init(
          postgresHostname: ProcessInfo.processInfo.environment["METRICS_TEST_POSTGRES_HOST"],
          postgresUsername: "admin_metrics_test", postgresPassword: "local-test-password",
          postgresDatabase: "admin_metrics_test", aggregateMetricsEnabled: "false"))
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "admin@example.com", password: "super-secret", confirmPassword: "super-secret"))
      #expect(try await database.users.administratorAccounts(["admin@example.com"]) == [user.id])
      let now = Date()
      let day = MetricCalendar.day(now)
      let success = MetricBucket(day: day, feature: .projects, statusClass: 2)
      let errors = MetricBucket(day: day, feature: .projects, statusClass: 5)
      try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<20 {
          group.addTask {
            try await database.adminMetrics.flush(
              [
                success: .init(count: 5, durationMilliseconds: 100),
                errors: .init(count: 1, durationMilliseconds: 30),
              ], now)
          }
        }
        try await group.waitForAll()
      }
      let snapshot = try await database.adminMetrics.snapshot(day, day)
      #expect(snapshot.accounts == 1)
      #expect(snapshot.projects == 0)
      #expect(snapshot.buckets[success] == .init(count: 100, durationMilliseconds: 2000))
      #expect(snapshot.buckets[errors] == .init(count: 20, durationMilliseconds: 600))
      let later = MetricCalendar.utc.date(byAdding: .month, value: 13, to: now)!
      try await database.adminMetrics.prune(later)
      #expect(try await database.adminMetrics.snapshot(day, day).buckets.isEmpty)
      try await app.autoRevert()
      try await app.asyncShutdown()
    } catch {
      try? await app.autoRevert()
      try? await app.asyncShutdown()
      throw error
    }
  }
}
