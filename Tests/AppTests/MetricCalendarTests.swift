import Foundation
import ManualDCore
import Testing

struct MetricCalendarTests {
  @Test(arguments: [
    ("2024-02-29T23:59:59Z", "2024-02-29"),
    ("2024-03-01T00:00:00Z", "2024-03-01"),
    ("2024-03-01T00:30:00+01:00", "2024-02-29"),
    ("2024-02-29T23:30:00-02:00", "2024-03-01"),
  ])
  func utcDay(timestamp: String, expected: String) throws {
    let date = try #require(ISO8601DateFormatter().date(from: timestamp))
    #expect(MetricCalendar.day(date) == expected)
  }

  @Test(arguments: [
    ("2024-02-29T12:00:00Z", "2023-02-28"),
    ("2025-02-28T12:00:00Z", "2024-02-28"),
    ("2024-03-01T00:00:00Z", "2023-03-01"),
    ("2025-01-01T00:00:00Z", "2024-01-01"),
  ])
  func retentionUsesCalendarMonths(timestamp: String, expected: String) throws {
    let date = try #require(ISO8601DateFormatter().date(from: timestamp))
    #expect(MetricCalendar.retentionStart(date) == expected)
  }
}
