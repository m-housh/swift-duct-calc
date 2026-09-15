import App
import DatabaseClient
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(.dependencies { $0.context = .live })
struct RequestErrorTests {
  @Test func duplicateTrunkNamesReturnRenameMessage() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "trunks@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let project = try await database.projects.create(
        user.id,
        .init(
          name: "Trunk tests", streetAddress: "1 Main", city: "Monroe", state: "OH",
          zipCode: "45050"))
      let trunk = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:], height: 8, name: "Main trunk"))
      let other = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .return, rooms: [:], height: 10, name: "Other trunk"))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=trunks%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
        "HX-Request": "true",
      ]
      let path = "/projects/\(project.id)/duct-sizing/trunk"
      for (method, url) in [(HTTPMethod.POST, path), (.PATCH, "\(path)/\(other.id)")] {
        let response = try await client.sendRequest(
          method, url, headers: headers,
          body: .init(
            string: "projectID=\(project.id)&type=return&name=Main+trunk&height=12"))
        #expect(response.status == .unprocessableEntity)
        let failure = try JSONDecoder().decode(
          PresentationError.self, from: Data(response.body.readableBytesView))
        #expect(
          failure.message
            == "A trunk with this name already exists in this project. Choose a different name.")
        #expect(try await database.trunkSizes.fetch(project.id).count == 2)
        #expect(try await database.trunkSizes.get(trunk.id) == trunk)
        #expect(try await database.trunkSizes.get(other.id) == other)
      }
    }
  }

  @Test func fallbackServerFailuresAreNotReportedAsMalformedForms() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .live())
      try await app.autoMigrate()
      app.post("signup") { _ async throws -> HTTPStatus in
        throw Abort(.internalServerError, reason: "private downstream failure")
      }
    }) { app in
      let response = try await app.testing().sendRequest(
        .POST, "/signup", headers: ["HX-Request": "true"])
      #expect(response.status == .internalServerError)
      #expect(response.body.string.contains("reference"))
      #expect(!response.body.string.contains("private downstream failure"))
    }
  }

  @Test func failedActionsReturnMessagesAndStatus() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "errors@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let project = try await database.projects.create(
        user.id,
        .init(
          name: "Error tests", streetAddress: "1 Main", city: "Monroe", state: "OH",
          zipCode: "45050"))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=errors%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
        "HX-Request": "true",
      ]
      let invalid = try await client.sendRequest(
        .POST, "/projects/\(project.id)/equipment",
        headers: headers,
        body: .init(string: "projectID=\(project.id)&staticPressure=1&heatingCFM=0"))
      #expect(invalid.status == .unprocessableEntity)
      #expect(
        invalid.headers.contentType?.description.hasPrefix("application/vnd.ductcalc.error+json")
          == true)
      #expect(invalid.headers.first(name: .cacheControl) == "no-store")
      let failure = try JSONDecoder().decode(
        PresentationError.self, from: Data(invalid.body.readableBytesView))
      #expect(failure.title == "Could not save equipment")
      #expect(
        failure.fields.contains { $0.name == "staticPressure" && $0.message.contains("in. w.c.") })
      #expect(failure.fields.contains { $0.name == "heatingCFM" })
      #expect(try await database.equipment.fetch(project.id) == nil)

      let malformedUpload = try await client.sendRequest(
        .POST, "/projects/\(project.id)/rooms/csv",
        headers: [
          "Cookie": String(cookie), "HX-Request": "true",
          "Content-Type": "multipart/form-data; boundary=test-upload",
        ],
        body: .init(
          string:
            "--test-upload\r\nContent-Disposition: form-data; name=\"missing\"\r\n\r\nfile\r\n--test-upload--\r\n"
        ))
      #expect(malformedUpload.status == .badRequest)

      let expired = try await client.sendRequest(
        .POST, "/projects/\(project.id)/equipment",
        headers: ["HX-Request": "true", "Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "projectID=\(project.id)&staticPressure=0.5&heatingCFM=900"))
      #expect(expired.status == .unauthorized)
      #expect(expired.body.string.contains("Sign in in another tab"))

      for email in ["errors%40example.test", "unknown%40example.test"] {
        let failedLogin = try await client.sendRequest(
          .POST, "/login",
          headers: ["HX-Request": "true", "Content-Type": "application/x-www-form-urlencoded"],
          body: .init(string: "email=\(email)&password=incorrect"))
        #expect(failedLogin.status == .unauthorized)
        #expect(failedLogin.body.string.contains("email address or password is incorrect"))
      }
      let missing = try await client.sendRequest(.GET, "/missing-page")
      #expect(missing.status == .notFound)
      #expect(missing.body.string.contains("Back to projects"))
      #expect(missing.body.string.contains("navbar"))
      #expect(!missing.body.string.contains("Routing "))
    }
  }

  @Test func accountCreationSurvivesFollowUpLoginFailure() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(
        app, in: .live(),
        makeDatabaseClient: { database in
          var client = DatabaseClient.live(database: database)
          client.users.login = { _ in throw PrivateFailure() }
          return client
        })
      try await app.autoMigrate()
    }) { app in
      let response = try await app.testing().sendRequest(
        .POST, "/signup",
        headers: ["HX-Request": "true", "Content-Type": "application/x-www-form-urlencoded"],
        body: .init(
          string:
            "email=saved-account%40example.test&password=super-secret&confirmPassword=super-secret")
      )
      #expect(response.status == .internalServerError)
      let failure = try JSONDecoder().decode(
        PresentationError.self, from: Data(response.body.readableBytesView))
      #expect(failure.title == "Account created")
      #expect(failure.message.contains("do not need to sign up again"))
      #expect(failure.actions == [.init("Sign in", href: "/login")])
      #expect(failure.reference != nil)
      #expect(!response.body.string.contains("private uploaded text"))
      let database = DatabaseClient.live(database: app.db)
      let token = try await database.users.login(
        .init(email: "saved-account@example.test", password: "super-secret"))
      #expect(try await database.users.get(token.userID)?.email == "saved-account@example.test")
    }
  }

  @Test func profileCreationDistinguishesValidationFromRefreshFailure() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(
        app, in: .live(),
        makeDatabaseClient: { database in
          var client = DatabaseClient.live(database: database)
          client.projects.fetch = { _, _ in throw PrivateFailure() }
          return client
        })
      try await app.autoMigrate()
    }) { app in
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "profile@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=profile%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "HX-Request": "true",
        "Content-Type": "application/x-www-form-urlencoded",
      ]
      let fields =
        "userID=\(user.id)&lastName=Tester&companyName=HVAC&streetAddress=1+Main&city=Monroe&state=OH&zipCode=45050"
      let invalid = try await client.sendRequest(
        .POST, "/signup/profile", headers: headers, body: .init(string: fields + "&firstName="))
      #expect(invalid.status == .unprocessableEntity)
      #expect(!invalid.body.string.contains("Change saved"))
      #expect(try await database.userProfiles.fetch(user.id) == nil)

      let saved = try await client.sendRequest(
        .POST, "/signup/profile", headers: headers, body: .init(string: fields + "&firstName=Test"))
      #expect(saved.status == .internalServerError)
      let failure = try JSONDecoder().decode(
        PresentationError.self, from: Data(saved.body.readableBytesView))
      #expect(failure.title == "Change saved")
      #expect(failure.message.contains("Reload the page before making this change again"))
      #expect(failure.reference != nil)
      #expect(!saved.body.string.contains("private uploaded text"))
      #expect(try await database.userProfiles.fetch(user.id)?.firstName == "Test")
    }
  }

  @Test func savedChangeSurvivesRefreshFailure() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(
        app, in: .live(),
        makeDatabaseClient: { database in
          let live = DatabaseClient.live(database: database)
          var client = live
          client.equipment.fetch = { id in
            if try await live.equipment.fetch(id) != nil { throw PrivateFailure() }
            return nil
          }
          return client
        })
      try await app.autoMigrate()
    }) { app in
      let database = DatabaseClient.live(database: app.db)
      let user = try await database.users.create(
        .init(
          email: "refresh@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let project = try await database.projects.create(
        user.id,
        .init(
          name: "Refresh tests", streetAddress: "1 Main", city: "Monroe", state: "OH",
          zipCode: "45050"))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=refresh%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let response = try await client.sendRequest(
        .POST, "/projects/\(project.id)/equipment",
        headers: [
          "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
          "HX-Request": "true",
        ],
        body: .init(string: "projectID=\(project.id)&staticPressure=0.5&heatingCFM=900"))
      #expect(response.status == .internalServerError)
      let failure = try JSONDecoder().decode(
        PresentationError.self, from: Data(response.body.readableBytesView))
      #expect(failure.title == "Change saved")
      #expect(failure.reference != nil)
      #expect(!response.body.string.contains("private uploaded text"))
      #expect(try await database.equipment.fetch(project.id)?.heatingCFM == 900)

      let page = try await client.sendRequest(
        .GET, "/projects/\(project.id)/equipment",
        headers: ["Cookie": String(cookie)])
      #expect(page.status == .internalServerError)
      #expect(page.body.string.contains("project-sidebar"))
      #expect(page.body.string.contains("Error reference"))
      #expect(!page.body.string.contains("Change saved"))
    }
  }
}

private struct PrivateFailure: LocalizedError {
  var errorDescription: String? { "private uploaded text" }
}
