import AuthClient
import Dependencies
import EnvVars
import Fluent
import Foundation
import ManualDCore
import Testing
import VaporTesting

@testable import App
@testable import DatabaseClient

@Suite
struct AdminMetricsTests {
  private let adminID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!

  @Test
  func failedFlushDoesNotReplayAnUncertainBatch() async throws {
    let probe = MetricsFlushProbe()
    var logger = Logger(label: "metrics-test")
    logger.logLevel = .critical
    var database = DatabaseClient.AdminMetrics()
    database.flush = { batch, _ in try await probe.flush(batch) }
    let recorder = AggregateMetricsRecorder(
      database: database, logger: logger)
    let now = Date()
    await recorder.record(
      feature: .projects, status: 200, milliseconds: 20, signup: false, now: now)
    await recorder.flush(now: now)
    await recorder.record(
      feature: .ductulator, status: 200, milliseconds: 30, signup: false, now: now)
    await recorder.flush(now: now)
    let saved = await probe.saved
    #expect(saved.keys.allSatisfy { $0.feature != .projects })
    #expect(
      saved[.init(day: MetricCalendar.day(now), feature: .ductulator, statusClass: 2)]?.count == 1)
  }

  @Test
  func accessAndPrivacy() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .init(adminEmails: " Admin@Example.com "))
      try await app.autoMigrate()
      try await UserModel(
        id: adminID, email: "admin@example.com", passwordHash: Bcrypt.hash("super-secret")
      )
      .save(on: app.db)
      _ = try await DatabaseClient.live(database: app.db).users.create(
        .init(
          email: "member@example.com", password: "super-secret", confirmPassword: "super-secret"))
    }) { app in
      try await app.asyncBoot()
      let client = try app.testing()
      // A newly created case variant cannot claim the configured email after startup.
      _ = try await DatabaseClient.live(database: app.db).users.create(
        .init(email: "ADMIN@example.com", password: "super-secret", confirmPassword: "super-secret")
      )
      let variantLogin = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=ADMIN%40example.com&password=super-secret"))
      let variantCookie = String(
        try #require(variantLogin.headers.first(name: .setCookie)).split(separator: ";")[0])
      let variant = try await client.sendRequest(.GET, "/admin", headers: ["Cookie": variantCookie])
      #expect(variant.status == .forbidden)
      let variantProjects = try await client.sendRequest(
        .GET, "/projects", headers: ["Cookie": variantCookie])
      #expect(!variantProjects.body.string.contains("href=\"/admin\""))
      let guest = try await client.sendRequest(.GET, "/admin")
      #expect(guest.status == .seeOther)
      #expect(guest.headers.first(name: .location) == "/login?next=%2Fadmin")
      #expect(guest.headers.first(name: .cacheControl) == "private, no-store")

      let memberLogin = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=member%40example.com&password=super-secret"))
      let memberCookie = String(
        try #require(memberLogin.headers.first(name: .setCookie)).split(separator: ";")[0])
      let denied = try await client.sendRequest(.GET, "/admin", headers: ["Cookie": memberCookie])
      #expect(denied.status == .forbidden)
      #expect(denied.headers.first(name: .cacheControl) == "private, no-store")

      let login = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=admin%40example.com&password=super-secret"))
      let cookie = String(
        try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0])
      let projects = try await client.sendRequest(.GET, "/projects", headers: ["Cookie": cookie])
      #expect(projects.body.string.contains("href=\"/admin\""))
      for days in [7, 30, 90] {
        let response = try await client.sendRequest(
          .GET, "/admin?days=\(days)", headers: ["Cookie": cookie])
        #expect(response.status == .ok)
        #expect(response.body.string.contains("Last \(days) days"))
        #expect(response.body.string.contains("Registered accounts"))
        #expect(!response.body.string.contains("@example.com"))
        #expect(!response.body.string.contains(adminID.uuidString))
        #expect(!response.body.string.contains("<script"))
        #expect(response.headers.first(name: .cacheControl) == "private, no-store")
        #expect(
          response.headers.first(name: "Content-Security-Policy")?.contains(
            "frame-ancestors 'none'") == true)
      }
      for days in ["-1", "365", "abc"] {
        let invalid = try await client.sendRequest(
          .GET, "/admin?days=\(days)", headers: ["Cookie": cookie])
        #expect(invalid.status == .badRequest)
      }
      let htmx = try await client.sendRequest(
        .GET, "/admin", headers: ["Cookie": cookie, "HX-Request": "true"])
      #expect(htmx.headers.first(name: "HX-Redirect") == "/admin?days=30")
      _ = try await client.sendRequest(.GET, "/logout", headers: ["Cookie": cookie])
      let loggedOut = try await client.sendRequest(.GET, "/admin", headers: ["Cookie": cookie])
      #expect(loggedOut.status == .seeOther)
    }
  }

  @Test
  func matchedRequestsAndSignupOnly() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .init())
      try await app.autoMigrate()
    }) { app in
      try await app.asyncBoot()
      let client = try app.testing()
      _ = try await client.sendRequest(.GET, "/")
      _ = try await client.sendRequest(.GET, "/health")
      _ = try await client.sendRequest(.GET, "/admin")
      _ = try await client.sendRequest(.GET, "/css/admin.css")
      _ = try await client.sendRequest(.GET, "/missing-private-name?email=secret%40example.com")
      let body = "email=signup%40example.com&password=super-secret&confirmPassword=super-secret"
      for _ in 0..<2 {
        _ = try await client.sendRequest(
          .POST, "/signup",
          headers: ["Content-Type": "application/x-www-form-urlencoded"], body: .init(string: body))
      }
      let recorder = try #require(app.storage[MetricsRecorderKey.self])
      await recorder.flush()
      let today = MetricCalendar.day(Date())
      let snapshot = try await DatabaseClient.live(database: app.db).adminMetrics.snapshot(
        today, today)
      #expect(snapshot.accounts == 1)
      #expect(
        snapshot.buckets.filter { $0.key.feature == .home }.values.reduce(0) { $0 + $1.count } == 1)
      #expect(
        snapshot.buckets.filter { $0.key.feature == .accounts }.values.reduce(0) { $0 + $1.count }
          == 2)
      #expect(snapshot.buckets[.init(day: today, feature: .signups, statusClass: 0)]?.count == 1)
      let rows = try await AdminMetricModel.query(on: app.db).all()
      #expect(Set(rows.map(\.feature)).isSubset(of: Set(MetricFeature.allCases.map(\.rawValue))))
      #expect(rows.allSatisfy { $0.durationMilliseconds >= 0 })
    }
  }

  @Test
  func disabledCollectionAndEmptyAllowlist() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .init(aggregateMetricsEnabled: "false"))
      try await app.autoMigrate()
      _ = try await DatabaseClient.live(database: app.db).users.create(
        .init(
          email: "member@example.com", password: "super-secret", confirmPassword: "super-secret"))
    }) { app in
      try await app.asyncBoot()
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=member%40example.com&password=super-secret"))
      let cookie = String(
        try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0])
      let denied = try await client.sendRequest(.GET, "/admin", headers: ["Cookie": cookie])
      #expect(denied.status == .forbidden)
      _ = try await client.sendRequest(.GET, "/")
      await app.storage[MetricsRecorderKey.self]?.flush()
      #expect(try await AdminMetricModel.query(on: app.db).count() == 0)
      #expect(try await AdminMetricState.query(on: app.db).count() == 0)
    }
  }

  @Test
  func concurrentRequestsAndThrownErrors() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .init())
      try await app.autoMigrate()
    }) { app in
      let recorder = try #require(app.storage[MetricsRecorderKey.self])
      let middleware = AggregateMetricsMiddleware(recorder: recorder)
      try await withThrowingTaskGroup(of: Void.self) { group in
        for index in 0..<100 {
          group.addTask {
            let request = Request(application: app, on: app.eventLoopGroup.next())
            request.storage[MetricFeatureKey.self] = .projects
            let next = AsyncBasicResponder { _ in
              if index % 2 == 0 { throw Abort(.serviceUnavailable) }
              return Response(status: .ok)
            }
            do { _ = try await middleware.respond(to: request, chainingTo: next) } catch {
              #expect(index % 2 == 0)
            }
          }
        }
        try await group.waitForAll()
      }
      await recorder.flush()
      let today = MetricCalendar.day(Date())
      let snapshot = try await DatabaseClient.live(database: app.db).adminMetrics.snapshot(
        today, today)
      #expect(snapshot.buckets[.init(day: today, feature: .projects, statusClass: 2)]?.count == 50)
      #expect(snapshot.buckets[.init(day: today, feature: .projects, statusClass: 5)]?.count == 50)
    }
  }
}

private actor MetricsFlushProbe {
  private var attempts = 0
  var saved: [MetricBucket: MetricCount] = [:]
  func flush(_ batch: [MetricBucket: MetricCount]) throws {
    attempts += 1
    if attempts == 1 { throw Abort(.serviceUnavailable) }
    saved = batch
  }
}
