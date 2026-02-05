import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

@Suite
struct TrunkSizeTests {

  @Test
  func happyPath() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database) var database

      let room = try await database.rooms.create(
        project.id,
        .init(
          name: "Test", heatingLoad: 12345, coolingTotal: 12345,
          coolingSensible: nil, registerCount: 5
        )
      )

      let trunk = try await database.trunkSizes.create(
        .init(
          projectID: project.id,
          type: .supply,
          rooms: [room.id: [1, 2, 3]],
          height: 8,
          name: "Test Trunk"
        )
      )

      let fetched = try await database.trunkSizes.fetch(project.id)
      #expect(fetched == [trunk])

      let got = try await database.trunkSizes.get(trunk.id)
      #expect(got == trunk)

      let updated = try await database.trunkSizes.update(
        trunk.id, .init(type: .return)
      )
      #expect(updated.type == .return)
      #expect(updated.id == trunk.id)

      try await database.trunkSizes.delete(trunk.id)
    }
  }

  @Test
  func notFound() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database.trunkSizes) var trunks

      await #expect(throws: NotFoundError.self) {
        try await trunks.create(
          .init(projectID: project.id, type: .supply, rooms: [UUID(0): [1]])
        )
      }

      await #expect(throws: NotFoundError.self) {
        try await trunks.delete(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await trunks.update(UUID(0), .init(type: .return))
      }
    }
  }

  @Test(
    arguments: [
      TrunkModel(projectID: UUID(0), type: .return, height: 8, name: ""),
      TrunkModel(projectID: UUID(0), type: .return, height: -8, name: "Test"),
    ]
  )
  func validations(model: TrunkModel) {
    #expect(throws: (any Error).self) {
      try model.validate()
    }
  }

  @Test(
    arguments: [
      TrunkRoomModel(trunkID: UUID(0), roomID: UUID(0), registers: [-1, 1], type: .return),
      TrunkRoomModel(trunkID: UUID(0), roomID: UUID(0), registers: [1, -1], type: .return),
      TrunkRoomModel(trunkID: UUID(0), roomID: UUID(0), registers: [], type: .return),
    ]
  )
  func trunkRoomModelValidations(model: TrunkRoomModel) {
    #expect(throws: (any Error).self) {
      try model.validate()
    }
  }
}
