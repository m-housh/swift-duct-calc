import App
import DatabaseClient
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(.dependencies { $0.context = .live })
struct FilterLookupRouteTests {
  @Test func addsAndReplacesFilterLossesAtEquipmentAirflow() async throws {
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
            name: "Filter test", streetAddress: "1 Test St", city: "Cincinnati", state: "OH",
            zipCode: "45202"))
      }
      let ownProject = try await project(owner.id)
      let foreignProject = try await project(other.id)
      let foreignFilter = try await db.componentLosses.create(
        .init(projectID: foreignProject.id, name: "filter", value: 0.1))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=owner%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
      ]
      for query in ["Aprilaire+213", "Aprilaire%20213"] {
        let result = try await client.sendRequest(.GET, "/filters?q=\(query)", headers: headers)
        #expect(result.status == .ok)
        #expect(result.body.string.contains("aria-label=\"Edit Aprilaire 213\""))
        #expect(result.body.string.contains("value=\"Aprilaire 213\""))
      }
      let literalPlus = try await client.sendRequest(
        .GET, "/filters?q=Aprilaire%2B213", headers: headers)
      #expect(literalPlus.status == .ok)
      #expect(!literalPlus.body.string.contains("aria-label=\"Edit Aprilaire 213\""))
      let route = "/projects/\(ownProject.id)/friction-rate/filters"
      func post(_ body: String) async throws -> TestingHTTPResponse {
        try await client.sendRequest(.POST, route, headers: headers, body: .init(string: body))
      }

      // Without airflow there is nothing to look the filter up at.
      _ = try await post("model=413")
      #expect(try await db.componentLosses.fetch(ownProject.id).isEmpty)
      let page = try await client.sendRequest(
        .GET, "/projects/\(ownProject.id)/friction-rate", headers: headers)
      #expect(page.body.string.contains("Enter heating or cooling airflow in Equipment first."))

      _ = try await db.equipment.create(
        .init(projectID: ownProject.id, heatingCFM: 900, coolingCFM: 1300))
      let added = try await post("model=413&replacing=")
      #expect(added.status == .ok)
      #expect(added.body.string.contains("Where the pressure goes"))
      let filter = try #require(try await db.componentLosses.fetch(ownProject.id).first)
      #expect(filter.name == "Aprilaire 413 filter")
      #expect(filter.value == 0.20)

      _ = try await post("model=516&replacing=\(filter.id)")
      let replaced = try await db.componentLosses.fetch(ownProject.id)
      #expect(replaced.count == 1)
      #expect(replaced.first?.name == "Aprilaire 516 filter")
      #expect(replaced.first?.value == 0.12)

      _ = try await post("model=unknown")
      _ = try await post("model=413&replacing=\(foreignFilter.id)")
      #expect(try await db.componentLosses.fetch(ownProject.id) == replaced)
      #expect(try await db.componentLosses.get(foreignFilter.id) == foreignFilter)
    }
  }
}
