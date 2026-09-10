import App
import DatabaseClient
import DependenciesTestSupport
import EnvVars
import Foundation
import Testing
import VaporTesting

@Suite(.dependencies { $0.date.now = Date(timeIntervalSince1970: 1_709_251_200) })
struct LoginRouteTests {
  @Test(arguments: [false, true])
  func loginRespectsSession(isHtmxRequest: Bool) async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .warning
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let database = DatabaseClient.live(database: app.db)
      _ = try await database.users.create(
        .init(
          email: "login@example.com", password: "super-secret", confirmPassword: "super-secret"))
      let client = try app.testing()
      var headers: HTTPHeaders = [:]
      if isHtmxRequest {
        headers.add(name: "HX-Request", value: "true")
      }

      let guest = try await client.sendRequest(.GET, "/login", headers: headers)
      #expect(guest.status == .ok)
      #expect(guest.body.string.contains("id=\"loginForm\""))

      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=login%40example.com&password=super-secret"))
      #expect(login.status == .ok)
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      headers.add(name: "Cookie", value: String(cookie))

      let home = try await client.sendRequest(.GET, "/", headers: headers)
      #expect(home.status == .ok)
      #expect(home.body.string.contains("hx-get=\"/login\""))

      for (path, destination) in [
        ("/login", "/projects"),
        (
          "/login?next=%2Ffittings%3Fsystem%3Dreturn%26data%3Djson",
          "/fittings?system=return&amp;data=json"
        ),
      ] {
        let response = try await client.sendRequest(.GET, path, headers: headers)
        #expect(response.status == .ok)
        #expect(!response.body.string.contains("id=\"loginForm\""))
        #expect(response.body.string.contains("hx-get=\"\(destination)\""))
        #expect(response.body.string.contains("hx-trigger=\"revealed\""))
        #expect(response.body.string.contains("hx-push-url=\"true\""))
      }

      let projects = try await client.sendRequest(.GET, "/projects", headers: headers)
      #expect(projects.status == .ok)
      #expect(!projects.body.string.contains("id=\"loginForm\""))

      let logout = try await client.sendRequest(.GET, "/logout", headers: headers)
      #expect(logout.status == .ok)
      let afterLogout = try await client.sendRequest(.GET, "/login", headers: headers)
      #expect(afterLogout.status == .ok)
      #expect(afterLogout.body.string.contains("id=\"loginForm\""))
    }
  }
}
