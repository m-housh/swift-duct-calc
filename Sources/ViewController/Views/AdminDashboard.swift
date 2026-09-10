import Elementary
import Foundation
import ManualDCore

/// A standalone document with local CSS and no scripts or external requests.
public struct AdminDashboard: HTMLDocument, Sendable {
  public var title: String { "Admin · Duct Calc" }
  public var lang: String { "en" }
  let snapshot: AdminMetricsSnapshot
  let days: Int
  let now: Date
  let metricsEnabled: Bool

  public init(snapshot: AdminMetricsSnapshot, days: Int, now: Date, metricsEnabled: Bool) {
    self.snapshot = snapshot
    self.days = days
    self.now = now
    self.metricsEnabled = metricsEnabled
  }

  public var head: some HTML {
    meta(.charset(.utf8))
    meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
    meta(.name("robots"), .content("noindex, nofollow"))
    link(.rel(.stylesheet), .href("/css/admin.css"))
  }

  private var dates: [String] {
    (0..<days).reversed().map {
      MetricCalendar.day(MetricCalendar.utc.date(byAdding: .day, value: -$0, to: now)!)
    }
  }

  private func total(feature: MetricFeature? = nil, day: String? = nil, errors: Bool = false)
    -> Int64
  {
    snapshot.buckets.reduce(0) { sum, item in
      let bucket = item.key
      guard feature.map { bucket.feature == $0 } ?? bucket.feature.isRequest,
        day.map({ bucket.day == $0 }) ?? true,
        !errors || bucket.statusClass == 5
      else { return sum }
      return sum + item.value.count
    }
  }

  private func average(feature: MetricFeature? = nil) -> String {
    let count = total(feature: feature)
    guard count > 0 else { return "—" }
    let duration = snapshot.buckets.reduce(0.0) { sum, item in
      (feature.map { item.key.feature == $0 } ?? item.key.feature.isRequest)
        ? sum + item.value.durationMilliseconds : sum
    }
    return String(format: "%.0f ms", duration / Double(count))
  }

  private func errorRate(feature: MetricFeature? = nil) -> String {
    let count = total(feature: feature)
    return count == 0
      ? "—"
      : String(
        format: "%.1f%%", 100 * Double(total(feature: feature, errors: true)) / Double(count))
  }

  private func covered(_ day: String) -> Bool {
    snapshot.buckets.keys.contains { $0.day == day }
  }

  public var body: some HTML {
    main(.class("admin")) {
      overview
      currentTotals
      periodSelector
      collectionStatus
      activityTotals
      featureTable
      dailyTable
      notes
    }
  }

  @HTMLBuilder
  private var overview: some HTML {
    nav(.class("admin-nav")) {
      a(.href("/projects")) { "← Duct Calc" }
      span { "Private admin" }
    }
    header {
      p(.class("eyebrow")) { "App overview" }
      h1 { "Usage at a glance" }
      p { "Aggregate account and app activity. Visitor estimates remain in Cloudflare." }
    }
  }

  @HTMLBuilder
  private var currentTotals: some HTML {
    section(.class("totals"), .init(name: "aria-label", value: "Current totals")) {
      article {
        h2 { "Registered accounts" }
        p(.class("number")) { "\(snapshot.accounts)" }
        p { "Accounts currently in the database" }
      }
      article {
        h2 { "Saved projects" }
        p(.class("number")) { "\(snapshot.projects)" }
        p { "Projects currently in the database" }
      }
    }
  }

  @HTMLBuilder
  private var periodSelector: some HTML {
    div(.class("period")) {
      h2 { "Last \(days) days" }
      nav(.init(name: "aria-label", value: "Date range")) {
        for range in [7, 30, 90] {
          a(
            .href("/admin?days=\(range)"), .class(range == days ? "selected" : ""),
            .init(name: "aria-current", value: range == days ? "page" : "false")
          ) {
            "\(range) days"
          }
        }
      }
    }
  }

  @HTMLBuilder
  private var collectionStatus: some HTML {
    p(.class("collection-status")) {
      if !metricsEnabled {
        "Collection is disabled. Previously collected data is shown below."
      } else if let last = snapshot.lastFlush {
        "Last saved: \(last.formatted(.iso8601)). Updates about once a minute."
        if now.timeIntervalSince(last) > 180 {
          " Collection appears delayed."
        }
      } else {
        "Waiting for the first collection interval. Current account and project totals are available."
      }
    }
  }

  @HTMLBuilder
  private var activityTotals: some HTML {
    section(.class("stats"), .init(name: "aria-label", value: "Activity totals")) {
      article {
        h3 { "Application requests" }
        p(.class("number")) { snapshot.buckets.isEmpty ? "—" : "\(total())" }
      }
      article {
        h3 { "New signups" }
        p(.class("number")) { snapshot.buckets.isEmpty ? "—" : "\(total(feature: .signups))" }
      }
      article {
        h3 { "Server error rate" }
        p(.class("number")) { errorRate() }
      }
      article {
        h3 { "Average response" }
        p(.class("number")) { average() }
      }
    }
  }

  @HTMLBuilder
  private var featureTable: some HTML {
    section(.class("panel")) {
      h2 { "Requests by feature" }
      div(.class("table-scroll")) {
        table {
          thead {
            tr {
              th { "Feature" }
              th { "Requests" }
              th { "5xx errors" }
              th { "Average response" }
            }
          }
          tbody {
            for feature in MetricFeature.allCases where feature.isRequest {
              tr {
                th(.scope(.row)) { feature.label }
                td { snapshot.buckets.isEmpty ? "—" : "\(total(feature: feature))" }
                td { errorRate(feature: feature) }
                td { average(feature: feature) }
              }
            }
          }
        }
      }
    }
  }

  @HTMLBuilder
  private var dailyTable: some HTML {
    section(.class("panel")) {
      h2 { "Daily activity" }
      p { "UTC dates, including today so far. A dash means no collection was recorded that day." }
      div(.class("daily-scroll")) {
        table {
          thead {
            tr {
              th { "Date" }
              th { "Requests" }
              th { "Signups" }
            }
          }
          tbody {
            let maxRequests = max(1, dates.map { total(day: $0) }.max() ?? 1)
            let maxSignups = max(1, dates.map { total(feature: .signups, day: $0) }.max() ?? 1)
            for day in dates.reversed() {
              tr {
                th(.scope(.row)) { day }
                td {
                  if covered(day) {
                    span { "\(total(day: day))" }
                    progress(
                      .init(name: "value", value: "\(total(day: day))"),
                      .init(name: "max", value: "\(maxRequests)"),
                      .init(name: "aria-label", value: "Requests on \(day)")
                    ) {}
                  } else {
                    "—"
                  }
                }
                td {
                  if covered(day) {
                    span { "\(total(feature: .signups, day: day))" }
                    progress(
                      .init(name: "value", value: "\(total(feature: .signups, day: day))"),
                      .init(name: "max", value: "\(maxSignups)"),
                      .init(name: "aria-label", value: "Signups on \(day)")
                    ) {}
                  } else {
                    "—"
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  @HTMLBuilder
  private var notes: some HTML {
    footer {
      p {
        "Counts are approximate and may be incomplete during outages or restarts. History begins when collection is enabled and is retained for 12 months. Deleted accounts remain in collected signup totals."
      }
      p {
        "Requests include automated traffic and HTMX updates on recognized app routes. Static files, health checks, admin pages, and unmatched requests are excluded. Response time measures server handling up to response creation, not download time. Errors count HTTP 5xx responses; validation messages returned with HTTP 200 are not included."
      }
      p {
        "Metrics contain daily counts and duration totals. They contain no account IDs, emails, IP addresses, project details, or individual browsing histories."
      }
    }
  }
}
