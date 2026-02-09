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
    } operation: { _, project in
      @Dependency(\.csvParser) var csvParser
      @Dependency(\.database) var database
      @Dependency(\.fileClient) var fileClient

      let csvPath = Bundle.module.path(forResource: "rooms", ofType: "csv")
      let csvFile = Room.CSV(file: try Data(contentsOf: URL(filePath: csvPath!)))
      let rows = try await csvParser.parseRooms(csvFile)
      let created = try await database.rooms.createFromCSV(project.id, rows)
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
