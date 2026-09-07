import Dependencies
import FileClient
import FittingClient
import Foundation
import ManualDCore
import ProjectClient
import Testing

@testable import DatabaseClient

struct FittingPathTests {
  func client() async throws -> FittingClient {
    try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    } operation: {
      try await .live()
    }
  }

  @Test func mixedPathsSaveReopenAndPreserveHistoricalValues() async throws {
    let fittings = try await client()
    try await withTestUserAndProject(setupDependencies: {
      $0.fittingClient = fittings
      $0.projectClient = .liveValue
    }) { user, project in
      @Dependency(\.database) var database
      @Dependency(\.projectClient) var projectClient
      let historical = try JSONDecoder().decode(
        [EquivalentLength.FittingGroup].self,
        from: Data("[{\"group\":4,\"letter\":\"AG\",\"value\":61.375,\"quantity\":2}]".utf8))
      #expect(historical[0].fitting == nil)
      let old = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Existing", type: .supply, straightLengths: [10],
          groups: historical))
      let saved = try await projectClient.saveFittingPath(
        user.id, project.id,
        .init(
          baseline: old, name: "Mixed", pathType: .supply, straightLengths: [10, 15],
          entries: [
            .saved(index: 0, quantity: 2), .reference(code: "4AG", feet: 19.125, quantity: 3),
            .catalog(
              id: "8O", inputs: .insideCornerOffset(radius: .mitered), column: nil, quantity: 1),
            .catalog(
              id: "11-junction-box",
              inputs: .flexJunctionBox(
                boxVelocity: .fpm700, openings: .sidewall, suppliedBend: true,
                bendVelocity: .fpm900, bendRadiusRatio: .one), column: nil, quantity: 2),
          ]))
      #expect(saved.groups[0].value == 61.375 && saved.groups[0].fitting?.origin == .legacy)
      #expect(saved.groups[1].value == 19.125 && saved.groups[1].fitting?.origin == .referenceEntry)
      #expect(saved.groups[3].value == 80 && saved.groups[3].letter.isEmpty)
      let reopened = try #require(try await database.equivalentLengths.get(saved.id))
      #expect(reopened.groups == saved.groups)
      #expect(reopened.totalEquivalentLength == 25 + 122.75 + 57.375 + saved.groups[2].value + 160)
      // A later catalog failure does not prevent a rename or quantity edit of saved snapshots.
      try await withDependencies {
        $0.fittingClient.evaluate = { _ in throw FittingPathErrorForTest.changedCatalog }
      } operation: {
        let renamed = try await projectClient.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: reopened, name: "Renamed", pathType: .supply,
            straightLengths: reopened.straightLengths,
            entries: reopened.groups.indices.map {
              .saved(index: $0, quantity: $0 == 0 ? 3 : reopened.groups[$0].quantity)
            }))
        #expect(renamed.groups[0].value == 61.375 && renamed.groups[0].quantity == 3)
        #expect(renamed.groups.map(\.fitting) == reopened.groups.map(\.fitting))
      }
    }
  }

  @Test func saveRejectsWrongOwnerForgedSavedRowsAndStaleBaselines() async throws {
    let fittings = try await client()
    try await withTestUserAndProject(setupDependencies: {
      $0.fittingClient = fittings
      $0.projectClient = .liveValue
    }) { user, project in
      @Dependency(\.database) var database
      @Dependency(\.projectClient) var projectClient
      let request = Fitting.PathSave(
        baseline: nil, name: "Path", pathType: .supply, straightLengths: [],
        entries: [.reference(code: "4AG", feet: 15.5, quantity: 1)])
      await #expect(throws: FittingPathError.self) {
        try await projectClient.saveFittingPath(UUID(), project.id, request)
      }
      await #expect(throws: FittingPathError.self) {
        try await projectClient.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: nil, name: "Forged", pathType: .supply, straightLengths: [],
            entries: [.saved(index: 0, quantity: 1)]))
      }
      let path = try await projectClient.saveFittingPath(user.id, project.id, request)
      _ = try await database.equivalentLengths.update(path.id, .init(name: "Changed elsewhere"))
      await #expect(throws: FittingPathError.self) {
        try await projectClient.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: path, name: "Overwrite", pathType: .supply, straightLengths: [],
            entries: [.saved(index: 0, quantity: 1)]))
      }
      let current = try #require(try await database.equivalentLengths.get(path.id))
      await #expect(throws: FittingPathError.self) {
        try await projectClient.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: current, name: "Wrong type", pathType: .return, straightLengths: [],
            entries: [.saved(index: 0, quantity: 1)]))
      }
      #expect(try await database.equivalentLengths.get(path.id) == current)
    }
  }

  @Test func returnContributionsAndUserFavoritesStayIndependent() async throws {
    let fittings = try await client()
    try await withTestUserAndProject(setupDependencies: {
      $0.fittingClient = fittings
      $0.projectClient = .liveValue
    }) { user, project in
      @Dependency(\.database) var database
      @Dependency(\.projectClient) var projectClient
      let path = try await projectClient.saveFittingPath(
        user.id, project.id,
        .init(
          baseline: nil, name: "Return", pathType: .return, straightLengths: [],
          entries: [
            .catalog(
              id: "6A", inputs: .returnJunction(branchCFM: 200, totalCFM: 1000), column: .branch,
              quantity: 1)
          ]))
      #expect(path.groups[0].fitting?.column == .branch)
      #expect(
        path.groups[0].value == path.groups[0].fitting?.returnJunction?.branch.equivalentLengthFeet)
      try await database.fittingFavorites.set(user.id, "8O", true)
      try await database.fittingFavorites.set(user.id, "8O", true)
      #expect(try await database.fittingFavorites.fetch(user.id) == ["8O"])
      #expect(try await database.fittingFavorites.fetch(UUID()) == [])
      try await database.fittingFavorites.set(user.id, "8O", false)
      #expect(try await database.fittingFavorites.fetch(user.id) == [])
    }
  }
  enum FittingPathErrorForTest: Error { case changedCatalog }
}
