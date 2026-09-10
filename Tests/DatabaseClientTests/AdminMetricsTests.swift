import Dependencies
import Fluent
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

@Suite
struct AdminMetricsDatabaseTests {
  @Test
  func retentionKeepsTheCutoffDay() async throws {
    try await withDatabase {
      @Dependency(\.database.adminMetrics) var metrics
      let expired = MetricBucket(day: "2023-02-28", feature: .projects, statusClass: 2)
      let retained = MetricBucket(day: "2023-03-01", feature: .projects, statusClass: 2)
      try await metrics.flush(
        [expired: .init(count: 1), retained: .init(count: 2)],
        Date(timeIntervalSince1970: 1_677_628_800))  // 2023-03-01 UTC
      let now = Date(timeIntervalSince1970: 1_709_251_200)  // 2024-03-01 UTC
      try await metrics.flush([:], now)
      let snapshot = try await metrics.snapshot("2023-02-28", "2023-03-01")
      #expect(snapshot.buckets[expired] == nil)
      #expect(snapshot.buckets[retained]?.count == 2)
    }
  }

  @Test
  func emailAllowlistRequiresOneExistingAccount() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database
      #expect(try await database.users.administratorAccounts([user.email]) == [user.id])
      await #expect(throws: (any Error).self) {
        try await database.users.administratorAccounts(["missing@example.com"])
      }
      _ = try await database.users.create(
        .init(
          email: "TESTY@example.com", password: "super-secret", confirmPassword: "super-secret"))
      await #expect(throws: (any Error).self) {
        try await database.users.administratorAccounts([user.email])
      }
    }
  }

  @Test
  func aggregationRetentionAndDeletion() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var database
      let now = Date(timeIntervalSince1970: 1_788_912_000)  // 2026-09-09 UTC
      let day = MetricCalendar.day(now)
      let bucket = MetricBucket(day: day, feature: .projects, statusClass: 2)
      let signups = MetricBucket(day: day, feature: .signups, statusClass: 0)
      let old = Date(timeIntervalSince1970: 1_700_000_000)
      let oldBucket = MetricBucket(day: MetricCalendar.day(old), feature: .projects, statusClass: 2)
      try await database.adminMetrics.flush([oldBucket: .init(count: 100)], old)
      try await database.adminMetrics.flush(
        [bucket: .init(count: 3, durationMilliseconds: 150), signups: .init(count: 1)], now)
      try await database.adminMetrics.flush(
        [bucket: .init(count: 2, durationMilliseconds: 250)], now)
      var snapshot = try await database.adminMetrics.snapshot("2000-01-01", day)
      #expect(snapshot.accounts == 1)
      #expect(snapshot.projects == 1)
      #expect(snapshot.buckets[bucket] == .init(count: 5, durationMilliseconds: 400))
      #expect(snapshot.buckets[oldBucket] == nil)
      #expect(snapshot.lastFlush == now)

      try await database.projects.delete(project.id)
      try await database.users.delete(user.id)
      snapshot = try await database.adminMetrics.snapshot(day, day)
      #expect(snapshot.accounts == 0)
      #expect(snapshot.projects == 0)
      #expect(snapshot.buckets[signups]?.count == 1)

      let later = MetricCalendar.utc.date(byAdding: .month, value: 13, to: now)!
      try await database.adminMetrics.prune(later)
      snapshot = try await database.adminMetrics.snapshot("2000-01-01", "2100-01-01")
      #expect(snapshot.buckets.isEmpty)
      // Retention also works without a new collection heartbeat.
      #expect(snapshot.lastFlush == now)
    }
  }
}
