import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

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

  @Test(arguments: ["heating", "cooling", "pressure"])
  func draftCanBeCompleted(first: String) async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database) var database
      let draft = try await database.equipment.create(
        .init(
          projectID: project.id,
          heatingCFM: first == "heating" ? 900 : nil,
          coolingCFM: first == "cooling" ? 1200 : nil))
      #expect(!draft.isComplete)
      #expect(throws: EquipmentInfo.Incomplete.self) { try draft.validatedAirflow() }
      #expect(try await database.projects.getCompletedSteps(project.id).equipmentInfo == false)
      #expect(try await database.equipment.fetch(project.id) == draft)
      let updated = try await database.equipment.update(draft.id, .init(staticPressure: 0.6))
      #expect(updated.heatingCFM == draft.heatingCFM)
      #expect(updated.coolingCFM == draft.coolingCFM)
      let complete = try await database.equipment.update(
        draft.id,
        .init(
          heatingCFM: first == "heating" ? nil : 900,
          coolingCFM: first == "cooling" ? nil : 1200))
      #expect(complete.id == draft.id && complete.staticPressure == 0.6)
      #expect(complete.heatingCFM == 900 && complete.coolingCFM == 1200)
      #expect(complete.isComplete)
      #expect(try await database.projects.getCompletedSteps(project.id).equipmentInfo)
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

  @Test(
    arguments: [
      EquipmentModel(staticPressure: 0.5, heatingCFM: 0, coolingCFM: nil, projectID: UUID(0)),
      EquipmentModel(staticPressure: 0.5, heatingCFM: nil, coolingCFM: 0, projectID: UUID(0)),
      EquipmentModel(staticPressure: -1, heatingCFM: 1000, coolingCFM: 1000, projectID: UUID(0)),
      EquipmentModel(staticPressure: 0.5, heatingCFM: -1, coolingCFM: 1000, projectID: UUID(0)),
      EquipmentModel(staticPressure: 0.5, heatingCFM: 1000, coolingCFM: -1000, projectID: UUID(0)),
      EquipmentModel(staticPressure: 1.1, heatingCFM: 1000, coolingCFM: -1000, projectID: UUID(0)),
    ]
  )
  func validations(model: EquipmentModel) {
    #expect(throws: (any Error).self) {
      try model.validate()
    }
  }

}
