import DatabaseClient
import Dependencies
import Foundation
import ManualDCore
import Testing

@Suite
struct EquivalentLengthTests {

  @Test
  func happyPath() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database.equivalentLengths) var equivalentLengths

      let equivalentLength = try await equivalentLengths.create(
        .init(
          projectID: project.id,
          name: "Test",
          type: .supply,
          straightLengths: [10],
          groups: [
            .init(group: 1, letter: "a", value: 20),
            .init(group: 2, letter: "a", value: 30, quantity: 2),
          ]
        )
      )

      let fetched = try await equivalentLengths.fetch(project.id)
      #expect(fetched == [equivalentLength])

      let got = try await equivalentLengths.get(equivalentLength.id)
      #expect(got == equivalentLength)

      var max = try await equivalentLengths.fetchMax(project.id)
      #expect(max.supply == equivalentLength)
      #expect(max.return == nil)

      let returnLength = try await equivalentLengths.create(
        .init(
          projectID: project.id,
          name: "Test",
          type: .return,
          straightLengths: [10],
          groups: [
            .init(group: 1, letter: "a", value: 20),
            .init(group: 2, letter: "a", value: 30, quantity: 2),
          ]
        )
      )
      max = try await equivalentLengths.fetchMax(project.id)
      #expect(max.supply == equivalentLength)
      #expect(max.return == returnLength)

      let updated = try await equivalentLengths.update(
        equivalentLength.id, .init(name: "Supply Test")
      )
      #expect(updated.name == "Supply Test")
      #expect(updated.id == equivalentLength.id)

      try await equivalentLengths.delete(equivalentLength.id)

    }
  }

  @Test
  func notFound() async throws {
    try await withDatabase {
      @Dependency(\.database.equivalentLengths) var equivalentLengths

      await #expect(throws: NotFoundError.self) {
        try await equivalentLengths.delete(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await equivalentLengths.update(UUID(0), .init())
      }
    }
  }
}
