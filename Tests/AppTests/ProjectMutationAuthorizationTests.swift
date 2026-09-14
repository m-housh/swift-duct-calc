import App
import DatabaseClient
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(.dependencies { $0.context = .live })
struct ProjectMutationAuthorizationTests {
  @Test func mutationsRejectForeignRecordsAndProfiles() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .critical
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let db = DatabaseClient.live(database: app.db)
      let owner = try await db.users.create(
        .init(
          email: "victim@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let other = try await db.users.create(
        .init(
          email: "attacker@example.test", password: "super-secret", confirmPassword: "super-secret")
      )
      let privateProject = try await db.projects.create(
        owner.id,
        .init(
          name: "Private victim project", streetAddress: "1 Test St", city: "Cincinnati",
          state: "OH", zipCode: "45202"))
      let ownProject = try await db.projects.create(
        other.id,
        .init(
          name: "Attacker project", streetAddress: "2 Test St", city: "Cincinnati", state: "OH",
          zipCode: "45202"))
      let room = try await db.rooms.create(
        privateProject.id,
        .init(name: "Private room", heatingLoad: 12000, coolingTotal: 6000, registerCount: 1))
      let trunk = try await db.trunkSizes.create(
        .init(
          projectID: privateProject.id, type: .supply, rooms: [room.id: [1]], name: "Private trunk")
      )
      let loss = try await db.componentLosses.create(
        .init(projectID: privateProject.id, name: "Private loss", value: 0.03))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=attacker%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
      ]
      let base = "/projects/\(ownProject.id)"
      _ = try await client.sendRequest(
        .DELETE, base + "/duct-sizing/trunk/\(trunk.id)", headers: headers)
      #expect(try await db.trunkSizes.get(trunk.id) == trunk)
      _ = try await client.sendRequest(
        .PATCH, base + "/component-loss/\(loss.id)", headers: headers,
        body: .init(string: "value=0.20"))
      #expect(try await db.componentLosses.get(loss.id)?.value == 0.03)
      _ = try await client.sendRequest(
        .PATCH, base + "/rooms/update-shr", headers: headers,
        body: .init(string: "projectID=\(privateProject.id)&sensibleHeatRatio=0.75"))
      #expect(
        try await db.projects.get(privateProject.id)?.sensibleHeatRatio
          == privateProject.sensibleHeatRatio)
      _ = try await client.sendRequest(.DELETE, base + "/rooms/\(room.id)", headers: headers)
      #expect(try await db.rooms.get(room.id) == room)
      let equipment = try await db.equipment.create(
        .init(projectID: privateProject.id, heatingCFM: 1000, coolingCFM: 1100))
      let changedEquipment = try await client.sendRequest(
        .PATCH, base + "/equipment/\(equipment.id)", headers: headers,
        body: .init(string: "coolingCFM=1600"))
      #expect(changedEquipment.status == .notFound)
      #expect(try await db.equipment.get(equipment.id) == equipment)
      for (suffix, body) in [
        (
          "/equipment",
          "projectID=\(privateProject.id)&heatingCFM=1000&coolingCFM=1200&staticPressure=0.50"
        ),
        ("/component-loss", "projectID=\(privateProject.id)&name=Injected&value=0.10"),
        ("/duct-sizing/trunk", "projectID=\(privateProject.id)&type=supply&name=Injected"),
      ] {
        let response = try await client.sendRequest(
          .POST, base + suffix, headers: headers, body: .init(string: body))
        #expect(response.status == .notFound)
      }
      let associate = try await client.sendRequest(
        .POST, base + "/duct-sizing/trunk", headers: headers,
        body: .init(
          string: "projectID=\(ownProject.id)&type=supply&name=Injected&rooms=\(room.id)_1"))
      #expect(!associate.body.string.contains("Private room"))
      #expect(try await db.trunkSizes.fetch(ownProject.id).isEmpty)
      let ownRoom = try await db.rooms.create(
        ownProject.id,
        .init(name: "Own room", heatingLoad: 12000, coolingTotal: 6000, registerCount: 1))
      for body in [
        "register=99&height=8", "register=0&height=8", "register=1&height=0",
        "register=1&height=-1",
      ] {
        let response = try await client.sendRequest(
          .POST, base + "/duct-sizing/room/\(ownRoom.id)", headers: headers,
          body: .init(string: body))
        #expect(response.status == .badRequest)
        #expect(try await db.rooms.get(ownRoom.id) == ownRoom)
      }
      let foreignRectangle = try await client.sendRequest(
        .POST, base + "/duct-sizing/room/\(room.id)", headers: headers,
        body: .init(string: "register=1&height=8"))
      #expect(foreignRectangle.status == .notFound)
      #expect(try await db.rooms.get(room.id) == room)
      for (body, status) in [
        ("height=8&rooms=\(ownRoom.id)_1&rooms=\(room.id)_1", HTTPStatus.notFound),
        ("height=8&rooms=\(ownRoom.id)_2", .badRequest),
        ("height=0&rooms=\(ownRoom.id)_1", .badRequest),
      ] {
        let response = try await client.sendRequest(
          .POST, base + "/duct-sizing/rectangular-sizes", headers: headers,
          body: .init(string: body))
        #expect(response.status == status)
        #expect(try await db.rooms.get(ownRoom.id) == ownRoom)
        #expect(try await db.rooms.get(room.id) == room)
      }
      let clearRoom = try await db.rooms.create(
        ownProject.id,
        .init(name: "Clear sizes", heatingLoad: 1000, coolingTotal: 800, registerCount: 3))
      _ = try await db.rooms.updateRectangularSize(clearRoom.id, .init(register: 1, height: 8))
      let sizedRoom = try await db.rooms.updateRectangularSize(
        clearRoom.id, .init(register: 2, height: 6))
      let foreignSizedRoom = try await db.rooms.updateRectangularSize(
        room.id, .init(register: 1, height: 8))
      for (body, status) in [
        ("rooms=\(clearRoom.id)_1&rooms=\(room.id)_1", HTTPStatus.notFound),
        ("rooms=\(clearRoom.id)_1&rooms=\(clearRoom.id)_4", .badRequest),
        ("rooms=\(clearRoom.id)_0", .badRequest),
      ] {
        let response = try await client.sendRequest(
          .POST, base + "/duct-sizing/rectangular-sizes/clear", headers: headers,
          body: .init(string: body))
        #expect(response.status == status)
        #expect(try await db.rooms.get(clearRoom.id) == sizedRoom)
        #expect(try await db.rooms.get(room.id) == foreignSizedRoom)
      }
      _ = try await client.sendRequest(
        .POST, base + "/duct-sizing/rectangular-sizes/clear", headers: headers,
        body: .init(
          string: "rooms=\(clearRoom.id)_1&rooms=\(clearRoom.id)_3&rooms=\(ownRoom.id)_1"))
      #expect(try await db.rooms.get(clearRoom.id)?.rectangularSizes
        == sizedRoom.rectangularSizes?.filter { $0.register == 2 })
      #expect(try await db.rooms.get(ownRoom.id) == ownRoom)
      #expect(try await db.rooms.get(room.id) == foreignSizedRoom)

      _ = try await db.rooms.update(clearRoom.id, .init(rectangularSizes: [.init(height: 10)]))
      _ = try await client.sendRequest(
        .POST, base + "/duct-sizing/rectangular-sizes", headers: headers,
        body: .init(string: "height=12&rooms=\(clearRoom.id)_1&rooms=\(clearRoom.id)_3"))
      let bulkSet = try #require(try await db.rooms.get(clearRoom.id)?.rectangularSizes)
      #expect(bulkSet.sorted { ($0.register ?? 0) < ($1.register ?? 0) }.map(\.height) == [12, 10, 12])
      #expect(bulkSet.allSatisfy { $0.register != nil })

      _ = try await db.rooms.update(clearRoom.id, .init(rectangularSizes: [.init(height: 10)]))
      _ = try await client.sendRequest(
        .POST, base + "/duct-sizing/rectangular-sizes/clear", headers: headers,
        body: .init(string: "rooms=\(clearRoom.id)_1&rooms=\(clearRoom.id)_3"))
      let bulkCleared = try #require(try await db.rooms.get(clearRoom.id)?.rectangularSizes)
      #expect(bulkCleared.count == 1)
      #expect(bulkCleared.first?.register == 2)
      #expect(bulkCleared.first?.height == 10)

      let profileResponse = try await client.sendRequest(
        .POST, "/signup/profile", headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(
          string:
            "userID=\(owner.id)&firstName=Forged&lastName=Profile&companyName=Test&streetAddress=1+Test+St&city=Cincinnati&state=OH&zipCode=45202&theme=dracula"
        ))
      #expect(try await db.userProfiles.fetch(owner.id) == nil)
      #expect(!profileResponse.body.string.contains("Private victim project"))
      #expect(profileResponse.status != .ok)
      let profile = try await db.userProfiles.create(
        .init(
          userID: owner.id, firstName: "Owner", lastName: "Test", companyName: "Company",
          streetAddress: "1 Test St", city: "Cincinnati", state: "OH", zipCode: "45202"))
      _ = try await client.sendRequest(
        .PATCH, "/profile/\(profile.id)", headers: headers,
        body: .init(string: "firstName=ChangedByOtherUser"))
      #expect(try await db.userProfiles.fetch(owner.id)?.firstName == "Owner")
    }
  }
}
