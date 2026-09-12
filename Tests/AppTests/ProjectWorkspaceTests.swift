import App
import DatabaseClient
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(
  .dependencies {
    $0.context = .live
    $0.date.now = Date(timeIntervalSince1970: 1_709_251_200)
  })
struct ProjectWorkspaceIntegrationTests {
  @Test func projectDirectorySearchAndMutationsRenderRealData() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .warning
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let database = DatabaseClient.live(database: app.db)
      let owner = try await database.users.create(
        .init(
          email: "owner@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let created = try await database.projects.create(
        owner.id,
        .init(
          name: "Cedar House", streetAddress: "248 Cedar Lane", city: "Loveland", state: "OH",
          zipCode: "45140", sensibleHeatRatio: 0.83))
      let project = try await database.projects.update(created.id, .init(sensibleHeatRatio: 0.83))
      let room = try await database.rooms.create(
        project.id,
        .init(name: "Living room", heatingLoad: 12000, coolingTotal: 6000, registerCount: 2))
      _ = try await database.equipment.create(
        .init(projectID: project.id, heatingCFM: 1000, coolingCFM: 1100))
      for loss in ComponentPressureLoss.Create.default(projectID: project.id) {
        _ = try await database.componentLosses.create(loss)
      }
      for type in EquivalentLength.EffectiveLengthType.allCases {
        _ = try await database.equivalentLengths.create(
          .init(
            projectID: project.id, name: "Longest \(type.rawValue)", type: type,
            straightLengths: [100],
            groups: [.init(group: type == .supply ? 1 : 5, letter: "A", value: 35)]))
      }
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=owner%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
      ]
      let base = "/projects/\(project.id)"
      for suffix in [
        "", "/rooms", "/equipment", "/effective-lengths", "/friction-rate", "/duct-sizing",
      ] {
        let response = try await client.sendRequest(.GET, base + suffix, headers: headers)
        #expect(response.status == .ok)
        #expect(response.body.string.contains("Cedar House"))
        #expect(response.body.string.contains("project-workspace"))
        #expect(!response.body.string.contains("Oops: Error"))
        if suffix == "/effective-lengths" {
          #expect(
            response.body.string.contains(
              "href=\"/path-templates?project=\(project.id)\">Manage templates")
          )
          #expect(!response.body.string.contains(">From template</a>"))
        }
      }
      let chooser = try await client.sendRequest(
        .GET, base + "/effective-lengths/guided", headers: headers)
      #expect(chooser.status == .ok)
      #expect(chooser.body.string.contains("Choose a path template"))
      #expect(chooser.body.string.contains("Default supply"))
      #expect(chooser.body.string.contains("Default return"))
      #expect(!chooser.body.string.contains("Use starter"))
      for type in [TrunkSize.TrunkType.supply, .return] {
        let trunk = try await database.trunkSizes.create(
          .init(
            projectID: project.id, type: type, rooms: [room.id: [1]],
            height: 8, name: "Test \(type.rawValue) trunk"))
        let sizing = try await client.sendRequest(.GET, base + "/duct-sizing", headers: headers)
        #expect(sizing.body.string.contains("aria-label=\"Delete Test \(type.rawValue) trunk\""))
        let deleted = try await client.sendRequest(
          .DELETE, base + "/duct-sizing/trunk/\(trunk.id)", headers: headers)
        #expect(deleted.status == .ok)
        #expect(deleted.body.string.contains("Supply &amp; return trunks"))
        #expect(!deleted.body.string.contains("aria-label=\"Delete Test \(type.rawValue) trunk\""))
        #expect(try await database.trunkSizes.get(trunk.id) == nil)
        #expect(try await database.rooms.get(room.id) != nil)
      }
      let results = try await client.sendRequest(
        .GET, "/projects/search?q=Cedar+House", headers: headers)
      #expect(results.status == .ok)
      #expect(results.body.string.contains("Cedar House"))
      #expect(!results.body.string.contains("No projects match"))
      for url in ["/projects/search?q=", "/projects/search", "/projects/search?q=%20%20"] {
        let cleared = try await client.sendRequest(.GET, url, headers: headers)
        #expect(cleared.status == .ok)
        #expect(cleared.body.string.contains("class=\"project-name\""))
        #expect(cleared.body.string.contains("Cedar House"))
        #expect(!cleared.body.string.contains("Routing error"))
      }
      let missing = try await client.sendRequest(
        .GET, "/projects/search?q=NoSuchProject", headers: headers)
      #expect(missing.status == .ok)
      #expect(missing.body.string.contains("No projects match your search."))
      #expect(!missing.body.string.contains("class=\"project-name\""))
      let page = try await client.sendRequest(.GET, "/projects/page?page=1&per=1", headers: headers)
      #expect(page.body.string.contains("Cedar House"))
      #expect(!page.body.string.contains("<table"))
      let rectangle = try await client.sendRequest(
        .POST, base + "/duct-sizing/room/\(room.id)", headers: headers,
        body: .init(string: "register=1&height=8"))
      #expect(rectangle.status == .ok)
      #expect(rectangle.body.string.contains("/projects/\(project.id)/duct-sizing/room/\(room.id)"))
      #expect(!rectangle.body.string.contains("Oops: Error"))
      let deleted = try await client.sendRequest(
        .DELETE, base + "/rooms/\(room.id)", headers: headers)
      #expect(deleted.body.string.contains("project-workspace"))
      #expect(
        !deleted.body.string.contains(
          "data-record=\"\(room.id.uuidString.replacingOccurrences(of: "-", with: ""))\""))
      #expect(try await database.projects.get(project.id)?.updatedAt == project.updatedAt)
    }
  }
}
