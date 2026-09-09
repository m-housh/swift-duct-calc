import CSVParser
import Dependencies
import FileClient
import Foundation
import ManualDCore
import Parsing
import Testing

@testable import DatabaseClient

@Suite
struct RoomTests {

  @Test
  func happyPath() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database.rooms) var rooms

      let room = try await rooms.create(
        project.id,
        .init(name: "Test", heatingLoad: 1234, coolingTotal: 1234)
      )

      let fetched = try await rooms.fetch(project.id)
      #expect(fetched == [room])

      let got = try await rooms.get(room.id)
      #expect(got == room)

      let updated = try await rooms.update(
        room.id,
        .init(rectangularSizes: [.init(id: UUID(0), register: 1, height: 8)])
      )
      #expect(updated.id == room.id)

      let updatedSize = try await rooms.updateRectangularSize(
        room.id, .init(id: UUID(0), register: 1, height: 10)
      )
      #expect(updatedSize.id == room.id)

      let deletedSize = try await rooms.deleteRectangularSize(room.id, UUID(0))
      #expect(deletedSize.rectangularSizes == nil)

      try await rooms.delete(room.id)

    }
  }

  @Test
  func createMany() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database.rooms) var rooms

      let created = try await rooms.createMany(
        project.id,
        [
          .init(name: "Test 1", heatingLoad: 1234, coolingTotal: 1234),
          .init(name: "Test 2", heatingLoad: 1234, coolingTotal: 1234),
        ]
      )

      #expect(created.count == 2)
      #expect(created[0].name == "Test 1")
      #expect(created[1].name == "Test 2")
    }
  }

  @Test
  func createFromCSV() async throws {
    try await withTestUserAndProject {
      $0.csvParser = .liveValue
    } operation: { user, project in
      @Dependency(\.csvParser) var csvParser
      @Dependency(\.database) var database
      @Dependency(\.fileClient) var fileClient

      let csvPath = Bundle.module.path(forResource: "rooms", ofType: "csv")
      let csvFile = Room.CSV(file: try Data(contentsOf: URL(filePath: csvPath!)))
      let rows = try await csvParser.parseRooms(csvFile)
      let created = try await database.rooms.createFromCSV(project.id, user.id, rows)
      #expect(created.count == rows.count)

      // Check that delegating to another room works properly.
      let bath = created.first(where: { $0.name == "Bath-1" })!
      let kitchen = created.first(where: { $0.name == "Kitchen" })!
      #expect(bath.delegatedTo == kitchen.id)
    }
  }

  @Test
  func notFound() async throws {
    try await withDatabase {
      @Dependency(\.database.rooms) var rooms

      await #expect(throws: NotFoundError.self) {
        try await rooms.delete(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await rooms.deleteRectangularSize(UUID(0), UUID(1))
      }

      await #expect(throws: NotFoundError.self) {
        try await rooms.update(UUID(0), .init())
      }

      await #expect(throws: NotFoundError.self) {
        try await rooms.updateRectangularSize(UUID(0), .init(height: 8))
      }
    }
  }

  @Test
  func importLoadsUpdatesMatchesAndRestoresDeletedRooms() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var database
      _ = try await database.projects.update(project.id, .init(sensibleHeatRatio: 0.83))
      let initial = Room.LoadImport(
        rooms: [
          .init(name: "Dining", level: 1, heatingLoad: 3846, coolingTotal: 1668),
          .init(name: "Kitchen", level: 1, heatingLoad: 3821, coolingTotal: 4085),
        ], sensibleHeatRatio: 0.88)
      let created = try await database.rooms.importLoads(project.id, user.id, initial)
      let dining = created[0]
      _ = try await database.rooms.update(
        dining.id,
        .init(heatingLoad: 1, coolingTotal: 2, coolingSensible: 1, registerCount: 2))
      _ = try await database.rooms.update(
        dining.id,
        .init(rectangularSizes: [.init(register: 1, height: 8)]))
      let powder = try await database.rooms.create(
        project.id,
        .init(
          name: "Powder", heatingLoad: 1, coolingTotal: 2, registerCount: 0, delegatedTo: dining.id)
      )
      let untouched = try await database.rooms.create(
        project.id,
        .init(name: "Keep me", heatingLoad: 500, coolingTotal: 200))
      let trunk = try await database.trunkSizes.create(
        .init(
          projectID: project.id, type: .supply, rooms: [dining.id: [1, 2]], name: "Dining trunk"))
      try await database.rooms.delete(created[1].id)
      let report = Room.LoadImport(
        rooms: [
          .init(name: "dining", level: 2, heatingLoad: 3846, coolingTotal: 1668),
          initial.rooms[1],
          .init(name: "Powder", level: 1, heatingLoad: 322, coolingTotal: 66),
        ], sensibleHeatRatio: 0.88)
      let imported = try await database.rooms.importLoads(project.id, user.id, report)
      #expect(imported[0].id == dining.id)
      #expect(imported[0].level == 2)
      #expect(imported[0].heatingLoad == 3846)
      #expect(imported[0].coolingLoad.total == 1668)
      #expect(imported[0].coolingLoad.sensible == nil)
      #expect(imported[0].registerCount == 2)
      #expect(imported[0].rectangularSizes?.first?.height == 8)
      #expect(imported[1].id != created[1].id)
      #expect(imported[1].registerCount == 1)
      #expect(imported[2].id == powder.id)
      #expect(imported[2].delegatedTo == dining.id)
      #expect(imported[2].registerCount == 0)
      #expect(try await database.rooms.get(untouched.id) == untouched)
      let updatedTrunk = try #require(try await database.trunkSizes.get(trunk.id))
      #expect(updatedTrunk.id == trunk.id)
      #expect(updatedTrunk.rooms.map(\.room.id) == trunk.rooms.map(\.room.id))
      #expect(updatedTrunk.rooms.map(\.registers) == trunk.rooms.map(\.registers))
      #expect(updatedTrunk.rooms.first?.room.heatingLoad == 3846)
      #expect(try await database.projects.getSensibleHeatRatio(project.id) == 0.83)
      await #expect(throws: NotFoundError.self) {
        try await database.rooms.importLoads(project.id, UUID(), report)
      }
      let repeated = try await database.rooms.importLoads(project.id, user.id, report)
      #expect(repeated.map(\.id) == imported.map(\.id))
      #expect(try await database.rooms.fetch(project.id).count == 4)
      await #expect(throws: (any Error).self) {
        try await database.rooms.importLoads(
          project.id, user.id,
          .init(rooms: [
            .init(name: "Dining", heatingLoad: 999, coolingTotal: 333),
            .init(name: "Invalid", heatingLoad: -1, coolingTotal: 10),
          ]))
      }
      #expect(try await database.rooms.get(dining.id)?.heatingLoad == 3846)
      #expect(try await database.rooms.fetch(project.id).count == 4)
    }
  }

  @Test
  func csvReimportUpdatesDistributionAndResolvesExistingTargets() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var database
      let kitchen = try await database.rooms.create(
        project.id,
        .init(name: "Kitchen", heatingLoad: 100, coolingTotal: 50, registerCount: 2))
      let bath = try await database.rooms.createFromCSV(
        project.id, user.id,
        [
          .init(
            name: "Bath", heatingLoad: 20, coolingTotal: 10, registerCount: 0,
            delegatedToName: "Kitchen")
        ])[0]
      #expect(bath.delegatedTo == kitchen.id)
      let imported = try await database.rooms.createFromCSV(
        project.id, user.id,
        [
          .init(name: "Kitchen", level: 1, heatingLoad: 200, coolingTotal: 80, registerCount: 3),
          .init(name: "Bath", level: 1, heatingLoad: 30, coolingTotal: 15, registerCount: 1),
        ])
      #expect(imported[0].id == kitchen.id)
      #expect(imported[0].registerCount == 3)
      #expect(imported[0].heatingLoad == 200)
      #expect(imported[1].id == bath.id)
      #expect(imported[1].registerCount == 1)
      #expect(imported[1].delegatedTo == nil)
      await #expect(throws: RoomImportError.self) {
        try await database.rooms.createFromCSV(
          project.id, user.id,
          [
            .init(name: "Kitchen", heatingLoad: 999, coolingTotal: 50, registerCount: 1),
            .init(
              name: "New", heatingLoad: 20, coolingTotal: 10, registerCount: 0,
              delegatedToName: "Missing"),
          ])
      }
      #expect(try await database.rooms.get(kitchen.id)?.heatingLoad == 200)
      #expect(try await database.rooms.fetch(project.id).count == 2)
      await #expect(throws: RoomImportError.self) {
        try await database.rooms.createFromCSV(
          project.id, user.id,
          [
            .init(name: "Kitchen", heatingLoad: 999, coolingTotal: 50, registerCount: 1),
            .init(name: "kitchen", heatingLoad: 999, coolingTotal: 50, registerCount: 1),
          ])
      }
    }
  }

  @Test
  func importLoadsInitializesSHRAndRollsBackOnFailure() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database
      let project = try await database.projects.create(
        user.id,
        .init(
          name: "PDF import", streetAddress: "123 Main St", city: "Test",
          state: "OH", zipCode: "45223"))
      let good = Room.Create(name: "Dining", heatingLoad: 3846, coolingTotal: 1668)
      let bad = Room.Create(name: "Kitchen", heatingLoad: -1, coolingTotal: 4085)
      await #expect(throws: (any Error).self) {
        try await database.rooms.importLoads(
          project.id, user.id, .init(rooms: [good, bad], sensibleHeatRatio: 0.88))
      }
      #expect(try await database.rooms.fetch(project.id).isEmpty)
      #expect(try await database.projects.getSensibleHeatRatio(project.id) == nil)

      await #expect(throws: RoomImportError.self) {
        try await database.rooms.importLoads(project.id, user.id, .init(rooms: [good]))
      }
      #expect(try await database.rooms.fetch(project.id).isEmpty)

      _ = try await database.rooms.importLoads(
        project.id, user.id, .init(rooms: [good], sensibleHeatRatio: 0.88))
      #expect(try await database.projects.getSensibleHeatRatio(project.id) == 0.88)
      #expect(try await database.rooms.fetch(project.id).count == 1)
    }
  }

  @Test(
    arguments: [
      Room.Create(
        // projectID: UUID(0),
        name: "",
        heatingLoad: 12345,
        coolingTotal: 12344,
        coolingSensible: nil,
        registerCount: 1
      ),
      Room.Create(
        // projectID: UUID(0),
        name: "Test",
        heatingLoad: -12345,
        coolingTotal: 12344,
        coolingSensible: nil,
        registerCount: 1
      ),
      Room.Create(
        // projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingTotal: -12344,
        coolingSensible: nil,
        registerCount: 1
      ),
      Room.Create(
        // projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingTotal: 12344,
        coolingSensible: -123,
        registerCount: 1
      ),
      Room.Create(
        // projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingTotal: 12344,
        coolingSensible: nil,
        registerCount: -1
      ),
      Room.Create(
        // projectID: UUID(0),
        name: "",
        heatingLoad: -12345,
        coolingTotal: -12344,
        coolingSensible: -1,
        registerCount: -1
      ),
      Room.Create(
        // projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingTotal: nil,
        coolingSensible: nil,
        registerCount: 1
      ),
    ]
  )
  func validations(room: Room.Create) throws {
    #expect(throws: (any Error).self) {
      // do {
      try room.toModel(projectID: UUID(0)).validate()
      // } catch {
      //   print("\(error)")
      //   throw error
      // }
    }
  }
}
