import DatabaseClient
import Dependencies
import Foundation
import ManualDCore
import Testing

@Suite
struct EquipmentTests {

  @Test
  func happyPath() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var database

      let equipment = try await database.equipment.create(
        .init(projectID: project.id, heatingCFM: 1000, coolingCFM: 1000)
      )

      let fetched = try await database.equipment.fetch(project.id)
      #expect(fetched == equipment)

      let got = try await database.equipment.get(equipment.id)
      #expect(got == equipment)

      let updated = try await database.equipment.update(
        equipment.id, .init(heatingCFM: 900)
      )
      #expect(updated.heatingCFM == 900)
      #expect(updated.id == equipment.id)

      try await database.equipment.delete(equipment.id)

    }
  }

  @Test
  func notFound() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database.equipment) var equipment

      let fetched = try await equipment.fetch(project.id)
      #expect(fetched == nil)

      await #expect(throws: NotFoundError.self) {
        try await equipment.delete(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await equipment.update(UUID(0), .init(staticPressure: 0.3))
      }
    }
  }

}
