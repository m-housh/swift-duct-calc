import DatabaseClient
import Dependencies
import Foundation
import ManualDClient
import ManualDCore
import ProjectClient
import Testing

struct DuctSizingTests {
  typealias Input = Project.DuctSizingUnavailable.Input

  @Test(
    arguments: Input.allCases.map { [$0] } + [
      [.supplyPath, .returnPath], [.equipment, .supplyPath, .returnPath], Input.allCases, [],
    ])
  func prerequisites(missing: [Input]) async throws {
    try await withTestUser(setupDependencies: {
      $0.projectClient = .liveValue
      $0.manualD = .liveValue
    }) { user in
      @Dependency(\.database) var database
      @Dependency(\.projectClient) var client
      let project = try await database.projects.create(
        user.id,
        .init(
          name: "Sizing project", streetAddress: "123 Main Street",
          city: "Monroe", state: "OH", zipCode: "45050"))
      if !missing.contains(.sensibleHeatRatio) {
        _ = try await database.projects.update(project.id, .init(sensibleHeatRatio: 0.833))
      }
      if !missing.contains(.equipment) {
        _ = try await database.equipment.create(
          .init(projectID: project.id, heatingCFM: 1000, coolingCFM: 1000))
      }
      if !missing.contains(.rooms) {
        let room = try await database.rooms.create(
          project.id, .init(name: "Bedroom", heatingLoad: 10000, coolingTotal: 10000))
        _ = try await database.trunkSizes.create(
          .init(projectID: project.id, type: .supply, rooms: [room.id: [1]], name: "Supply trunk"))
      }
      if !missing.contains(.supplyPath) {
        _ = try await database.equivalentLengths.create(
          .init(
            projectID: project.id, name: "Supply", type: .supply,
            straightLengths: [100], groups: []))
      }
      if !missing.contains(.returnPath) {
        _ = try await database.equivalentLengths.create(
          .init(
            projectID: project.id, name: "Return", type: .return,
            straightLengths: [100], groups: []))
      }
      if !missing.contains(.componentLosses) {
        for loss in ComponentPressureLoss.Create.default(projectID: project.id) {
          _ = try await database.componentLosses.create(loss)
        }
      }

      if missing.isEmpty {
        let sizes = try await client.calculateDuctSizes(project.id)
        let room = try #require(sizes.rooms.first)
        #expect(sizes.rooms.count == 1)
        #expect(room.heatingCFM == 1000)
        #expect(room.coolingCFM == 1000)
        #expect(room.ductSize.finalSize > 0)
        #expect(sizes.trunks.count == 1)
        #expect(sizes.trunks.first?.ductSize.finalSize == room.ductSize.finalSize)
      } else {
        for trunks in [false, true] {
          do {
            if trunks {
              _ = try await client.calculateTrunkDuctSizes(project.id)
            } else {
              _ = try await client.calculateRoomDuctSizes(project.id)
            }
            Issue.record("Expected missing sizing inputs")
          } catch let error as Project.DuctSizingUnavailable {
            #expect(Set(error.missingInputs) == Set(missing))
            let erased: any Error = error
            #expect(erased.localizedDescription.contains(missing[0].rawValue))
          }
        }
      }
    }
  }

  @Test func missingProject() async throws {
    try await withDatabase(setupDependencies: { $0.projectClient = .liveValue }) {
      @Dependency(\.projectClient) var client
      for trunks in [false, true] {
        do {
          if trunks {
            _ = try await client.calculateTrunkDuctSizes(UUID(999))
          } else {
            _ = try await client.calculateRoomDuctSizes(UUID(999))
          }
          Issue.record("Expected project not found")
        } catch let error as ProjectClientError {
          let erased: any Error = error
          #expect(erased.localizedDescription == "Project not found. id: \(UUID(999))")
        }
      }
    }
  }
}
