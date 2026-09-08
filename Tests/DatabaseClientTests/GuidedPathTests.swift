import DatabaseClient
import Dependencies
import FittingClient
import Foundation
import ManualDCore
import ProjectClient
import Testing

@Suite
struct GuidedPathTests {
  static var configuration: PathTemplate.Configuration {
    .init(
      name: "Test supply", type: .supply,
      steps: [
        .init(
          id: UUID(50), title: "Connection", group: .supplyConnection,
          choices: [.init(fittingID: "1B")]),
        .init(
          id: UUID(51), title: "Elbows", group: .elbow, behavior: .quantities, allowsSkipping: true,
          choices: [.init(fittingID: "8A-smooth")]),
      ])
  }
  static var rows: [GuidedPath.Row] {
    [
      .init(id: UUID(60), stepID: UUID(50), fittingID: "1B", inputs: .fixed, quantity: 1),
      .init(
        id: UUID(61), stepID: UUID(51), fittingID: "8A-smooth",
        inputs: .sourceTable(choices: ["0.75", "20"]), quantity: 3),
    ]
  }

  @Test
  func saveReopenAndEditPreserveCalculatedValuesAndTemplateSnapshot() async throws {
    try await withTestUserAndProject(setupDependencies: { $0.templateFittingClient = .liveValue }) {
      user, project in
      @Dependency(\.database) var database
      let client = ProjectClient.liveValue
      let template = try await client.createPathTemplate(
        userID: user.id, configuration: Self.configuration)
      let snapshot = PathTemplate.Snapshot(template: template)
      let pathName = String(repeating: "Supply ", count: 25)
      let saved = try await client.saveGuidedPath(
        userID: user.id, projectID: project.id,
        request: .init(
          name: pathName, straightLengths: [10], snapshot: snapshot,
          rows: Array(Self.rows.reversed())
        ))
      #expect(saved.name == pathName)
      #expect(abs(saved.totalEquivalentLength - 38.6) < 1e-9)
      #expect(saved.groups[1].calculation?.equivalentLengthFeet == 6.2)
      #expect(saved.groups[1].rowID == UUID(61))
      #expect(saved.templateSnapshot == snapshot)
      #expect(
        saved.groups[1].fitting?.calculation == saved.groups[1].calculation?.catalogCalculation)
      #expect(saved.groups[1].fitting?.calculation?.catalogRevision == "fitting-catalog-v14")
      await #expect(throws: FittingPathError.self) {
        try await client.saveFittingPath(
          user.id, project.id,
          .init(
            baseline: saved, name: saved.name, pathType: .supply,
            straightLengths: saved.straightLengths,
            entries: saved.groups.indices.map {
              .saved(index: $0, quantity: saved.groups[$0].quantity)
            }))
      }
      #expect(try await database.equivalentLengths.get(saved.id) == saved)
      var changed = template.configuration
      changed.steps.reverse()
      _ = try await client.updatePathTemplate(
        userID: user.id, id: template.id, revision: template.revision, configuration: changed
      )
      try await database.pathTemplates.delete(user.id, template.id)
      let updated = try await withDependencies {
        $0.templateFittingClient.evaluate = { _ in throw UnexpectedEvaluation() }
      } operation: {
        try await client.saveGuidedPath(
          userID: user.id, projectID: project.id,
          request: .init(
            id: saved.id, name: "Renamed path", straightLengths: [20], snapshot: snapshot,
            rows: Self.rows
          ))
      }
      #expect(updated.groups == saved.groups)
      #expect(updated.templateSnapshot == snapshot)
      #expect(abs(updated.totalEquivalentLength - 48.6) < 1e-9)
    }
  }

  @Test
  func invalidAndIncompleteRowsDoNotSaveAPath() async throws {
    try await withTestUserAndProject(setupDependencies: { $0.templateFittingClient = .liveValue }) {
      user, project in
      @Dependency(\.database) var database
      let client = ProjectClient.liveValue
      let template = try await client.createPathTemplate(
        userID: user.id, configuration: Self.configuration)
      let snapshot = PathTemplate.Snapshot(template: template)
      for rows in [
        [], [Self.rows[0], Self.rows[0]],
        [
          GuidedPath.Row(
            id: UUID(60), stepID: UUID(50), fittingID: "1A", inputs: .fixed, quantity: 1)
        ],
      ] {
        await #expect(throws: ValidationError.self) {
          try await client.saveGuidedPath(
            userID: user.id, projectID: project.id,
            request: .init(
              name: "Invalid path", straightLengths: [10], snapshot: snapshot, rows: rows
            ))
        }
      }
      let saved = try await database.equivalentLengths.fetch(project.id)
      #expect(saved.isEmpty)
    }
  }

  @Test
  func savingToAnotherUsersProjectIsRejected() async throws {
    try await withTestUserAndProject(setupDependencies: { $0.templateFittingClient = .liveValue }) {
      user, project in
      @Dependency(\.database) var database
      let other = try await database.users.create(
        .init(email: "other@example.com", password: "super-secret", confirmPassword: "super-secret")
      )
      let client = ProjectClient.liveValue
      let template = try await client.createPathTemplate(
        userID: other.id, configuration: Self.configuration)
      await #expect(throws: NotFoundError.self) {
        try await client.saveGuidedPath(
          userID: other.id, projectID: project.id,
          request: .init(
            name: "Wrong owner", straightLengths: [], snapshot: .init(template: template),
            rows: Self.rows
          ))
      }
      #expect(try await database.equivalentLengths.fetch(project.id).isEmpty)
    }
  }

  @Test
  func legacyRowsDecodeWithoutInventedCatalogMetadata() throws {
    let data = Data(
      """
      [{"group":8,"letter":"A","value":10.25,"quantity":2}]
      """.utf8)
    let rows = try JSONDecoder().decode([EquivalentLength.FittingGroup].self, from: data)
    #expect(rows[0].rowID == nil)
    #expect(rows[0].calculation == nil)
    #expect(rows.totalEquivalentLength == 20.5)
  }

  private struct UnexpectedEvaluation: Error {}
}
