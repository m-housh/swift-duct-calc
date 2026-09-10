import Foundation

/// Only these labels may enter aggregate storage. Never derive labels from request data.
public enum MetricFeature: String, CaseIterable, Codable, Sendable {
  case home, accounts, projects, ductulator, fittings, templates
  case signups, coverage

  public var label: String {
    switch self {
    case .home: "Home"
    case .accounts: "Account pages"
    case .projects: "Projects"
    case .ductulator: "Ductulator"
    case .fittings: "Fittings"
    case .templates: "Path templates"
    case .signups: "New signups"
    case .coverage: "Collection coverage"
    }
  }

  public var isRequest: Bool { self != .signups && self != .coverage }
}

public struct MetricBucket: Hashable, Sendable {
  public let day: String
  public let feature: MetricFeature
  public let statusClass: Int

  public init(day: String, feature: MetricFeature, statusClass: Int) {
    self.day = day
    self.feature = feature
    self.statusClass = statusClass
  }
}

public struct MetricCount: Sendable, Equatable {
  public var count: Int64
  public var durationMilliseconds: Double

  public init(count: Int64 = 0, durationMilliseconds: Double = 0) {
    self.count = count
    self.durationMilliseconds = durationMilliseconds
  }
}

public enum MetricCalendar {
  public static var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  public static func day(_ date: Date) -> String {
    let parts = utc.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }

  public static func retentionStart(_ date: Date) -> String {
    day(utc.date(byAdding: .month, value: -12, to: date)!)
  }
}

public struct AdminMetricsSnapshot: Sendable {
  public let accounts: Int
  public let projects: Int
  public let buckets: [MetricBucket: MetricCount]
  public let lastFlush: Date?

  public init(accounts: Int, projects: Int, buckets: [MetricBucket: MetricCount], lastFlush: Date?)
  {
    self.accounts = accounts
    self.projects = projects
    self.buckets = buckets
    self.lastFlush = lastFlush
  }
}
