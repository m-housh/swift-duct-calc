import App
import DatabaseClient
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(.dependencies { $0.context = .live })
struct FrictionRateTemplateIntegrationTests {
  @Test func applyingSwitchingAndReapplyingTemplates() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let db = DatabaseClient.live(database: app.db)
      let owner = try await db.users.create(
        .init(
          email: "owner@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let other = try await db.users.create(
        .init(
          email: "other@example.test", password: "super-secret", confirmPassword: "super-secret"))
      func project(_ userID: User.ID) async throws -> Project {
        try await db.projects.create(
          userID,
          .init(
            name: "Template test", streetAddress: "1 Test St", city: "Cincinnati",
            state: "OH", zipCode: "45202"))
      }
      let ownProject = try await project(owner.id)
      let foreignProject = try await project(other.id)
      let foreignLosses = try await db.componentLosses.fetch(foreignProject.id)
      _ = try await db.componentLosses.create(
        .init(projectID: ownProject.id, name: "Custom loss", value: 0.12))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=owner%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
      ]
      let created = try await client.sendRequest(
        .POST, "/projects", headers: headers,
        body: .init(
          string:
            "name=New+empty+project&streetAddress=1+Test+St&city=Cincinnati&state=OH&zipCode=45202")
      )
      #expect(created.status == .ok)
      let newProject = try #require(
        try await db.projects.fetch(owner.id, .first).items.first {
          $0.name == "New empty project"
        })
      #expect(try await db.componentLosses.fetch(newProject.id).isEmpty)
      #expect(try await !db.projects.getCompletedSteps(newProject.id).frictionRate)
      let empty = try await client.sendRequest(
        .GET, "/projects/\(newProject.id)/friction-rate", headers: headers)
      #expect(empty.body.string.contains("Choose your starting point"))
      #expect(empty.body.string.contains("Start from scratch"))
      let base = "/projects/\(ownProject.id)/friction-rate/templates/"
      for template in [FrictionRateTemplate.furnace, .airHandler, .airHandler, .shared] {
        let response = try await client.sendRequest(
          .POST, base + template.rawValue, headers: headers)
        #expect(response.status == .ok)
        #expect(response.body.string.contains("Where the pressure goes"))
        #expect(!response.body.string.contains("Oops: Error"))
        let losses = try await db.componentLosses.fetch(ownProject.id)
        let expected: [String: Double] =
          template == .shared
          ? ["supply-outlet": 0.03, "return-grille": 0.03, "balancing-damper": 0.03]
          : template == .furnace
            ? [
              "supply-outlet": 0.03, "return-grille": 0.03, "balancing-damper": 0.03,
              "evaporator-coil": 0.2, "filter": 0.1,
            ]
            : [
              "supply-outlet": 0.03, "return-grille": 0.03, "balancing-damper": 0.03, "filter": 0.1,
            ]
        #expect(losses.count == expected.count)
        #expect(losses.allSatisfy { expected[$0.name] == $0.value })
      }
      let before = try await db.componentLosses.fetch(ownProject.id)
      _ = try await client.sendRequest(.GET, base + "furnace", headers: headers)
      _ = try await client.sendRequest(.POST, base + "unknown", headers: headers)
      _ = try await client.sendRequest(.POST, base + "furnace")
      #expect(try await db.componentLosses.fetch(ownProject.id) == before)
      let denied = try await client.sendRequest(
        .POST, "/projects/\(foreignProject.id)/friction-rate/templates/furnace", headers: headers)
      #expect(denied.status == .notFound)
      #expect(try await db.componentLosses.fetch(foreignProject.id) == foreignLosses)
      let loss = try #require(before.first)
      _ = try await db.componentLosses.update(loss.id, .init(value: 0.15))
      #expect(try await db.componentLosses.get(loss.id)?.value == 0.15)
    }
  }
}
