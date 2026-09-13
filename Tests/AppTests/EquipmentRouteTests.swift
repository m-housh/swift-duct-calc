import App
import DatabaseClient
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(.dependencies { $0.context = .live })
struct EquipmentRouteTests {
  @Test(arguments: ["heatingCFM=900", "coolingCFM=1200", ""])
  func independentCreation(first: String) async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let db = DatabaseClient.live(database: app.db)
      let user = try await db.users.create(
        .init(
          email: "equipment@example.test",
          password: "super-secret", confirmPassword: "super-secret"))
      let project = try await db.projects.create(
        user.id,
        .init(
          name: "Equipment project",
          streetAddress: "1 Main", city: "Monroe", state: "OH", zipCode: "45050"))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=equipment%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
      ]
      let base = "/projects/\(project.id)/equipment"
      for invalid in ["heatingCFM=0", "coolingCFM=-1", "heatingCFM=garbage"] {
        _ = try await client.sendRequest(
          .POST, base, headers: headers,
          body: .init(string: "projectID=\(project.id)&staticPressure=0.5&\(invalid)"))
        #expect(try await db.equipment.fetch(project.id) == nil)
      }
      let response = try await client.sendRequest(
        .POST, base, headers: headers,
        body: .init(
          string: "projectID=\(project.id)&staticPressure=0.5\(first.isEmpty ? "" : "&" + first)"))
      #expect(response.status == .ok)
      let draft = try #require(try await db.equipment.fetch(project.id))
      #expect(!draft.isComplete)
      #expect(draft.heatingCFM == (first.hasPrefix("heating") ? 900 : nil))
      #expect(draft.coolingCFM == (first.hasPrefix("cooling") ? 1200 : nil))
      let update = try await client.sendRequest(
        .PATCH, base + "/\(draft.id)", headers: headers,
        body: .init(string: "heatingCFM=950&coolingCFM=1250&staticPressure=0.6"))
      #expect(update.status == .ok)
      let complete = try #require(try await db.equipment.fetch(project.id))
      #expect(complete.isComplete && complete.heatingCFM == 950 && complete.coolingCFM == 1250)
      #expect(try await db.projects.getCompletedSteps(project.id).equipmentInfo)
      for invalid in ["heatingCFM=0", "coolingCFM=-1", "staticPressure=1", "heatingCFM=garbage"] {
        _ = try await client.sendRequest(
          .PATCH, base + "/\(draft.id)", headers: headers,
          body: .init(string: invalid))
        #expect(try await db.equipment.fetch(project.id) == complete)
      }
    }
  }
}
