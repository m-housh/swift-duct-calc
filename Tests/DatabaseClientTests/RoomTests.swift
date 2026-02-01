import Dependencies
import Foundation
import ManualDCore
import Testing
import Validations

@testable import DatabaseClient

@Suite
struct RoomTests {

  @Test
  func happyPath() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database.rooms) var rooms

      let room = try await rooms.create(
        .init(projectID: project.id, name: "Test", heatingLoad: 1234, coolingTotal: 1234)
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
        projectID: UUID(0),
        name: "",
        heatingLoad: 12345,
        coolingTotal: 12344,
        coolingSensible: nil,
        registerCount: 1
      ),
      Room.Create(
        projectID: UUID(0),
        name: "Test",
        heatingLoad: -12345,
        coolingTotal: 12344,
        coolingSensible: nil,
        registerCount: 1
      ),
      Room.Create(
        projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingTotal: -12344,
        coolingSensible: nil,
        registerCount: 1
      ),
      Room.Create(
        projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingTotal: 12344,
        coolingSensible: -123,
        registerCount: 1
      ),
      Room.Create(
        projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingTotal: 12344,
        coolingSensible: nil,
        registerCount: -1
      ),
      Room.Create(
        projectID: UUID(0),
        name: "",
        heatingLoad: -12345,
        coolingTotal: -12344,
        coolingSensible: -1,
        registerCount: -1
      ),
    ]
  )
  func validations(room: Room.Create) throws {
    #expect(throws: (any Error).self) {
      // do {
      try room.toModel().validate()
      // } catch {
      //   print("\(error)")
      //   throw error
      // }
    }
  }

  // @Test(
  //   arguments: [
  //     Room.Update(
  //       name: "",
  //       heatingLoad: 12345,
  //       coolingTotal: 12344,
  //       coolingSensible: nil,
  //       registerCount: 1
  //     ),
  //     Room.Update(
  //       name: "Test",
  //       heatingLoad: -12345,
  //       coolingTotal: 12344,
  //       coolingSensible: nil,
  //       registerCount: 1
  //     ),
  //     Room.Update(
  //       name: "Test",
  //       heatingLoad: 12345,
  //       coolingTotal: -12344,
  //       coolingSensible: nil,
  //       registerCount: 1
  //     ),
  //     Room.Update(
  //       name: "Test",
  //       heatingLoad: 12345,
  //       coolingTotal: 12344,
  //       coolingSensible: -123,
  //       registerCount: 1
  //     ),
  //     Room.Update(
  //       name: "Test",
  //       heatingLoad: 12345,
  //       coolingTotal: 12344,
  //       coolingSensible: nil,
  //       registerCount: -1
  //     ),
  //     Room.Update(
  //       name: "",
  //       heatingLoad: -12345,
  //       coolingTotal: -12344,
  //       coolingSensible: -1,
  //       registerCount: -1
  //     ),
  //   ]
  // )
  // func updateValidations(room: Room.Update) throws {
  //   #expect(throws: (any Error).self) {
  //     // do {
  //     try room.validate()
  //     // } catch {
  //     //   print("\(error)")
  //     //   throw error
  //     // }
  //   }
  // }
}
