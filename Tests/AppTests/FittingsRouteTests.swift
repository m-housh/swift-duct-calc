import App
import DatabaseClient
import EnvVars
import ManualDCore
import Testing
import URLRouting
import VaporTesting

@Suite
struct FittingsRouteTests {
  private func configuredApp(_ app: Application) async throws {
    app.logger.logLevel = .warning
    try await configure(app, in: .live())
    try await app.autoMigrate()
  }

  @Test
  func publicReferenceAndProtectedProjects() async throws {
    try await withApp(configure: configuredApp) { app in
      let client = try app.testing()
      let response = try await client.sendRequest(
        .GET, "/fittings?system=return&group=8&fitting=8A-smooth&data=json")
      #expect(response.status == .ok)
      #expect(response.body.string.contains("data-tools=\"disabled\""))
      #expect(response.body.string.contains("/fittings/app.js"))
      #expect(response.body.string.contains("/css/output.css"))
      #expect(response.body.string.contains("/images/mand_logo_sm.webp"))
      #expect(response.body.string.contains("support@ductcalc.pro"))
      #expect(response.body.string.contains("data-theme=\"default\""))
      #expect(!response.body.string.contains("DESIGN LAB"))
      #expect(!response.body.string.contains("/prototypes/"))
      #expect(!response.body.string.contains(".pdf"))
      #expect(response.headers.first(name: .cacheControl) == "private, no-store")
      #expect(response.headers.first(name: .vary) == "Cookie, HX-Request")

      let projects = try await client.sendRequest(.GET, "/projects")
      #expect(projects.headers.first(name: .location)?.hasPrefix("/login?next=") == true)

      let script = try await client.sendRequest(.GET, "/fittings/app.js")
      #expect(script.status == .ok)
      #expect(script.body.string.contains("canUseData"))
    }
  }

  @Test
  func loginRestoresUserOnPublicPagesAndLogoutClearsIt() async throws {
    try await withApp(configure: configuredApp) { app in
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "reference@example.com", password: "super-secret", confirmPassword: "super-secret")
      )
      _ = try await database.userProfiles.create(
        .init(
          userID: user.id, firstName: "Reference", lastName: "Reader", companyName: "Reference Co",
          streetAddress: "123 Main St", city: "Cincinnati", state: "OH", zipCode: "45202",
          theme: .nord
        ))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(
          string:
            "email=reference%40example.com&password=super-secret&next=%2Ffittings%3Fsystem%3Dreturn%26data%3Djson"
        ))
      #expect(login.status == .ok)
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = ["Cookie": String(cookie)]

      let reference = try await client.sendRequest(.GET, "/fittings?data=json", headers: headers)
      #expect(reference.status == .ok)
      #expect(reference.body.string.contains("data-tools=\"enabled\""))
      #expect(reference.body.string.contains("/projects"))
      #expect(reference.body.string.contains("data-theme=\"nord\""))

      let ductulator = try await client.sendRequest(.GET, "/ductulator", headers: headers)
      #expect(ductulator.status == .ok)
      #expect(ductulator.body.string.contains("/profile"))

      let projects = try await client.sendRequest(.GET, "/projects", headers: headers)
      #expect(projects.status == .ok)

      let logout = try await client.sendRequest(.GET, "/logout", headers: headers)
      #expect(logout.status == .ok)
      let afterLogout = try await client.sendRequest(.GET, "/fittings?data=json", headers: headers)
      #expect(afterLogout.body.string.contains("data-tools=\"disabled\""))
    }
  }

  @Test
  func deletedUserSessionFallsBackToGuest() async throws {
    try await withApp(configure: configuredApp) { app in
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "deleted@example.com", password: "super-secret", confirmPassword: "super-secret"))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=deleted%40example.com&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let token = try await database.users.login(.init(email: user.email, password: "super-secret"))
      try await database.users.logout(token.id)
      try await database.users.delete(user.id)
      let headers: HTTPHeaders = ["Cookie": String(cookie)]
      let reference = try await client.sendRequest(.GET, "/fittings", headers: headers)
      #expect(reference.status == .ok)
      #expect(reference.body.string.contains("data-tools=\"disabled\""))
      let protected = try await client.sendRequest(.GET, "/projects", headers: headers)
      #expect(protected.headers.first(name: .location)?.hasPrefix("/login?next=") == true)
    }
  }

  @Test
  func htmxContinuationLoadsTheWholeDocument() async throws {
    try await withApp(configure: configuredApp) { app in
      let path = "/fittings?system=supply&fitting=1F&data=json"
      let response = try await app.testing().sendRequest(
        .GET, path, headers: ["HX-Request": "true"])
      #expect(response.status == .ok)
      #expect(response.headers.first(name: "HX-Redirect") == path)
      #expect(response.headers.first(name: .cacheControl) == "private, no-store")
    }
  }

  @Test
  func referenceDoesNotInterceptPickerFragmentsOrReviewGuards() async throws {
    try await withApp(configure: configuredApp) { app in
      let client = try app.testing()
      let fragment = try await client.sendRequest(
        .POST, "/fittings/group",
        headers: ["Content-Type": "application/x-www-form-urlencoded", "HX-Request": "true"],
        body: .init(string: "payload=%7B%22pathType%22%3A%22supply%22%2C%22groupID%22%3A4%7D"))
      #expect(fragment.status == .ok)
      #expect(fragment.headers.first(name: "HX-Redirect") == nil)
      #expect(fragment.body.string.contains("data-catalog-id=\"4G\""))
      #expect(fragment.body.string.contains("data-duct-shape=\"round\""))
      #expect(!fragment.body.string.contains("fittings-page"))
      let landing = try await client.sendRequest(.GET, "/fittings/picker")
      #expect(landing.body.string.contains("Fittings in your project"))
      for path in [
        "/fittings/review?group=4",
        "/projects/00000000-0000-0000-0000-000000000001/effective-lengths/editor",
      ] {
        let protected = try await client.sendRequest(.GET, path)
        #expect(protected.headers.first(name: .location)?.hasPrefix("/login?next=") == true)
      }
      let reviewSave = try await client.sendRequest(
        .POST, "/fittings/review", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "payload=%7B%7D"))
      #expect(reviewSave.headers.first(name: .location)?.hasPrefix("/login?next=") == true)
    }
  }

  @Test
  func queryStateRoundTrips() throws {
    let route = SiteRoute.View.fittingReference(
      .init(
        system: "supply", group: "8", fitting: "8A-smooth", q: "round & smooth",
        type: "conditional", data: "json"))
    let path = SiteRoute.View.router.path(for: route)
    #expect(path.hasPrefix("/fittings?"))
    #expect(try SiteRoute.View.router.parse(URLRequestData(string: path)!) == route)
    #expect(
      try SiteRoute.View.router.parse(URLRequestData(string: "/fittings")!)
        == .fittingReference(.init()))
  }
}
