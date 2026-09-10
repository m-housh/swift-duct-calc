import Fluent
import Foundation
import ManualDCore
import SQLKit

extension DatabaseClient.AdminMetrics {
  public static func live(database: any Database) -> Self {
    .init(
      snapshot: { fromDay, throughDay in
        let accounts = try await UserModel.query(on: database).count()
        let projects = try await ProjectModel.query(on: database).count()
        let rows = try await AdminMetricModel.query(on: database)
          .filter(\.$day >= fromDay).filter(\.$day <= throughDay).all()
        var buckets: [MetricBucket: MetricCount] = [:]
        for row in rows {
          guard let feature = MetricFeature(rawValue: row.feature) else { continue }
          buckets[.init(day: row.day, feature: feature, statusClass: row.statusClass)] = .init(
            count: row.count, durationMilliseconds: row.durationMilliseconds)
        }
        let state = try await AdminMetricState.find("collection", on: database)
        return .init(
          accounts: accounts, projects: projects, buckets: buckets,
          lastFlush: state.map { Date(timeIntervalSince1970: $0.lastFlush) })
      },
      flush: { buckets, now in
        try await database.transaction { transaction in
          guard let sql = transaction as? any SQLDatabase else {
            throw MetricsDatabaseError.unsupportedDatabase
          }
          let cutoff = MetricCalendar.retentionStart(now)
          // Stable lock ordering also avoids deadlocks between concurrent process flushes.
          let ordered = buckets.sorted {
            ($0.key.day, $0.key.feature.rawValue, $0.key.statusClass)
              < ($1.key.day, $1.key.feature.rawValue, $1.key.statusClass)
          }
          for (bucket, value) in ordered where bucket.day >= cutoff {
            // Both supported databases implement ON CONFLICT. Addition happens in the database,
            // so simultaneous flushes from different app processes cannot overwrite each other.
            try await sql.raw(
              """
              INSERT INTO admin_metrics (id, day, feature, status_class, count, duration_ms)
              VALUES (\(bind: UUID()), \(bind: bucket.day), \(bind: bucket.feature.rawValue),
                      \(bind: bucket.statusClass), \(bind: value.count), \(bind: value.durationMilliseconds))
              ON CONFLICT (day, feature, status_class) DO UPDATE SET
                count = admin_metrics.count + excluded.count,
                duration_ms = admin_metrics.duration_ms + excluded.duration_ms
              """
            ).run()
          }
          try await sql.raw(
            """
            INSERT INTO admin_metric_state (id, last_flush)
            VALUES ('collection', \(bind: now.timeIntervalSince1970))
            ON CONFLICT (id) DO UPDATE SET last_flush =
              CASE WHEN excluded.last_flush > admin_metric_state.last_flush
                   THEN excluded.last_flush ELSE admin_metric_state.last_flush END
            """
          ).run()
          try await AdminMetricModel.query(on: transaction).filter(\.$day < cutoff).delete()
        }
      },
      prune: { now in
        try await AdminMetricModel.query(on: database)
          .filter(\.$day < MetricCalendar.retentionStart(now)).delete()
      }
    )
  }
}

private enum MetricsDatabaseError: Error {
  case unsupportedDatabase
}

final class AdminMetricModel: Model, @unchecked Sendable {
  static let schema = "admin_metrics"
  @ID(key: .id) var id: UUID?
  @Field(key: "day") var day: String
  @Field(key: "feature") var feature: String
  @Field(key: "status_class") var statusClass: Int
  @Field(key: "count") var count: Int64
  @Field(key: "duration_ms") var durationMilliseconds: Double
  init() {}
}

final class AdminMetricState: Model, @unchecked Sendable {
  static let schema = "admin_metric_state"
  @ID(custom: "id", generatedBy: .user) var id: String?
  @Field(key: "last_flush") var lastFlush: Double
  init() {}
}

struct AdminMetricsMigration: AsyncMigration {
  func prepare(on database: any Database) async throws {
    try await database.schema(AdminMetricModel.schema)
      .id().field("day", .string, .required).field("feature", .string, .required)
      .field("status_class", .int, .required).field("count", .int64, .required)
      .field("duration_ms", .double, .required)
      .unique(on: "day", "feature", "status_class").create()
    try await database.schema(AdminMetricState.schema)
      .field("id", .string, .identifier(auto: false))
      .field("last_flush", .double, .required).create()
  }

  func revert(on database: any Database) async throws {
    try await database.schema(AdminMetricState.schema).delete()
    try await database.schema(AdminMetricModel.schema).delete()
  }
}
