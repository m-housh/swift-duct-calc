import AuthClient
import DatabaseClient
import Dependencies
import Elementary
import Foundation
import ManualDCore
import Vapor
import ViewController

func addAdminRoutes(
  to app: Application, database: DatabaseClient, administratorEmails: Set<String>,
  metricsEnabled: Bool
) {
  let access = AdminAccess(database: database.users, emails: administratorEmails)
  app.storage[AdminAccessKey.self] = access
  app.lifecycle.use(AdminAccessLifecycle(access: access))
  app.get("admin") { request async throws -> Response in
    @Dependency(\.auth) var auth
    @Dependency(\.date.now) var currentDate
    let headers: HTTPHeaders = [
      "Cache-Control": "private, no-store", "Vary": "Cookie, HX-Request",
      "X-Robots-Tag": "noindex, nofollow", "Referrer-Policy": "no-referrer",
    ]
    guard (try? auth.currentUser()) != nil else {
      let response = Response(status: .seeOther, headers: headers)
      response.headers.replaceOrAdd(name: .location, value: "/login?next=%2Fadmin")
      return response
    }
    guard await auth.isAdministrator() else {
      return Response(status: .forbidden, headers: headers, body: .init(string: "Access denied"))
    }
    let days: Int
    do {
      days = try request.query.get(Int?.self, at: "days") ?? 30
      guard [7, 30, 90].contains(days) else { throw Abort(.badRequest) }
    } catch {
      return Response(
        status: .badRequest, headers: headers, body: .init(string: "Choose 7, 30, or 90 days"))
    }
    if request.isHtmxRequest {
      let response = Response(status: .ok, headers: headers)
      response.headers.replaceOrAdd(name: "HX-Redirect", value: "/admin?days=\(days)")
      return response
    }
    let now = currentDate
    let from = MetricCalendar.utc.date(byAdding: .day, value: -(days - 1), to: now)!
    do {
      let snapshot = try await database.adminMetrics.snapshot(
        MetricCalendar.day(from), MetricCalendar.day(now))
      let page = AdminDashboard(
        snapshot: snapshot, days: days, now: now, metricsEnabled: metricsEnabled)
      let response = Response(status: .ok, headers: headers, body: .init(string: page.render()))
      response.headers.contentType = .html
      response.headers.replaceOrAdd(
        name: "Content-Security-Policy",
        value:
          "default-src 'none'; style-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"
      )
      return response
    } catch {
      request.logger.warning("Admin metrics could not be loaded")
      return Response(
        status: .serviceUnavailable, headers: headers,
        body: .init(string: "Metrics are temporarily unavailable. Please try again shortly."))
    }
  }
}

/// Resolve configured emails only at startup. Signup does not verify email ownership,
/// so matching arbitrary future accounts by email would allow privilege escalation.
actor AdminAccess {
  private let database: DatabaseClient.Users
  private let emails: Set<String>
  private var accountIDs: Set<UUID> = []

  init(database: DatabaseClient.Users, emails: Set<String>) {
    self.database = database
    self.emails = emails
  }

  func load() async throws {
    guard !emails.isEmpty else { return }
    do {
      accountIDs = try await database.administratorAccounts(emails)
    } catch {
      throw EnvError(
        "ADMIN_EMAILS must each match exactly one existing account; check the database and configuration"
      )
    }
  }

  func allows(_ id: UUID) -> Bool { accountIDs.contains(id) }
}

private struct AdminAccessLifecycle: LifecycleHandler {
  let access: AdminAccess
  func willBootAsync(_ application: Application) async throws { try await access.load() }
}

struct AdminAccessKey: StorageKey {
  typealias Value = AdminAccess
}
