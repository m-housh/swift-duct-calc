import Dependencies
import FileClient
import FittingClient
import Foundation
import ManualDCore
import ProjectClient
import Testing

@testable import DatabaseClient

struct FittingPathTests {
  @Test(arguments: [false, true])
  func templatePathsUseTheFittingEditorWithoutChangingUntouchedValues(legacyMetadata: Bool)
    async throws
  {
    let fittings = try await client()
    try await withTestUserAndProject(setupDependencies: {
      $0.fittingClient = fittings
      $0.templateFittingClient = .live(using: fittings)
    }) { user, project in
      @Dependency(\.database) var database
      let client = ProjectClient.liveValue
      let template = try await client.createPathTemplate(
        userID: user.id, configuration: GuidedPathTests.configuration)
      let snapshot = PathTemplate.Snapshot(template: template)
      var original = try await client.saveGuidedPath(
        userID: user.id, projectID: project.id,
        request: .init(
          name: "Template supply", straightLengths: [10, 25], snapshot: snapshot,
          rows: GuidedPathTests.rows))
      if legacyMetadata {
        let groups = original.groups.map { group in
          EquivalentLength.FittingGroup(
            group: group.group, letter: group.letter, value: group.value, quantity: group.quantity,
            rowID: group.rowID, stepID: group.stepID,
            calculation: group.calculation.map {
              .init(
                fittingID: $0.fittingID, inputs: $0.inputs,
                equivalentLengthFeet: $0.equivalentLengthFeet, ruleRevision: "historical")
            })
        }
        original = try await database.equivalentLengths.updateIfUnchanged(
          original, .init(groups: groups))
      }
      let unchanged = try await client.saveFittingPath(
        user.id, project.id,
        .init(
          baseline: original, name: original.name, pathType: .supply, straightLengths: [10, 25],
          entries: original.groups.indices.map {
            .saved(index: $0, quantity: original.groups[$0].quantity)
          }))
      #expect(unchanged.groups == original.groups)
      #expect(unchanged.templateSnapshot == snapshot)
      let copy = try await client.saveFittingPath(
        user.id, project.id,
        .init(
          baseline: unchanged, name: "Supply copy", pathType: unchanged.type,
          straightLengths: unchanged.straightLengths,
          entries: unchanged.groups.indices.map {
            .saved(index: $0, quantity: unchanged.groups[$0].quantity)
          }, duplicate: true))
      #expect(copy.id != unchanged.id)
      #expect(copy.groups == unchanged.groups)
      #expect(copy.straightLengths == unchanged.straightLengths)
      #expect(copy.templateSnapshot == snapshot)
      _ = try await client.saveFittingPath(
        user.id, project.id,
        .init(
          baseline: copy, name: "Edited copy", pathType: copy.type, straightLengths: [5],
          entries: [.saved(index: 0, quantity: 3)]))
      #expect(try await database.equivalentLengths.get(unchanged.id) == unchanged)
      await #expect(throws: FittingPathError.self) {
        try await client.saveFittingPath(
          UUID(), project.id,
          .init(
            baseline: unchanged, name: "Unauthorized copy", pathType: unchanged.type,
            straightLengths: [], entries: [], duplicate: true))
      }
      await #expect(throws: FittingPathError.self) {
        try await client.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: nil, name: "Missing source", pathType: .supply,
            straightLengths: [], entries: [], duplicate: true))
      }
      let edited = try await client.saveFittingPath(
        user.id, project.id,
        .init(
          baseline: unchanged, name: "Edited supply", pathType: .supply, straightLengths: [30],
          entries: [
            .catalog(id: "1B", inputs: .fixed, column: nil, quantity: 2, replacing: 0),
            .saved(index: 1, quantity: 1),
            .reference(code: "4AG", feet: 12.5, quantity: 1),
          ]))
      #expect(
        edited.groups[0].fitting?.id == (original.groups[0].fitting?.id ?? original.groups[0].rowID)
      )
      #expect(edited.groups[1].calculation == original.groups[1].calculation)
      #expect(abs(edited.totalEquivalentLength - 68.7) < 1e-9)
      let removed = try await client.saveFittingPath(
        user.id, project.id,
        .init(
          baseline: edited, name: edited.name, pathType: .supply, straightLengths: [30],
          entries: [.saved(index: 1, quantity: 1)]))
      #expect(removed.groups == [edited.groups[1]])
      #expect(removed.templateSnapshot == snapshot)
      #expect(try await database.pathTemplates.get(user.id, template.id) == template)
      #expect(try await database.equivalentLengths.get(removed.id) == removed)
      await #expect(throws: FittingPathError.self) {
        try await client.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: edited, name: "Stale overwrite", pathType: .supply, straightLengths: [],
            entries: []))
      }
    }
  }

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
        let edited = try await projectClient.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: renamed, name: "Edited reference", pathType: .supply,
            straightLengths: renamed.straightLengths,
            entries: renamed.groups.indices.map {
              $0 == 1
                ? .reference(code: "4AG", feet: 99.5, quantity: 1, replacing: 1)
                : .saved(index: $0, quantity: renamed.groups[$0].quantity)
            }))
        #expect(edited.groups[1].fitting?.id == renamed.groups[1].fitting?.id)
        #expect(edited.groups[1].value == 99.5)

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
