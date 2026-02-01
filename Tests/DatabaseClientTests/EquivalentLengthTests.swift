import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

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

  @Test(
    arguments: [
      EquivalentLength.Create(
        projectID: UUID(0), name: "", type: .return, straightLengths: [], groups: []
      ),
      EquivalentLength.Create(
        projectID: UUID(0), name: "Testy", type: .return, straightLengths: [-1, 1], groups: []
      ),
      EquivalentLength.Create(
        projectID: UUID(0), name: "Testy", type: .return, straightLengths: [1, -1], groups: []
      ),
      EquivalentLength.Create(
        projectID: UUID(0), name: "Testy", type: .return, straightLengths: [1, 1],
        groups: [
          .init(group: -1, letter: "a", value: 1.0, quantity: 1)
        ]
      ),
      EquivalentLength.Create(
        projectID: UUID(0), name: "Testy", type: .return, straightLengths: [1, 1],
        groups: [
          .init(group: 1, letter: "1", value: 1.0, quantity: 1)
        ]
      ),
      EquivalentLength.Create(
        projectID: UUID(0), name: "Testy", type: .return, straightLengths: [1, 1],
        groups: [
          .init(group: 1, letter: "a", value: -1.0, quantity: 1)
        ]
      ),
      EquivalentLength.Create(
        projectID: UUID(0), name: "Testy", type: .return, straightLengths: [1, 1],
        groups: [
          .init(group: 1, letter: "a", value: 1.0, quantity: -1)
        ]
      ),
    ]
  )
  func validations(model: EquivalentLength.Create) {
    #expect(throws: (any Error).self) {
      try model.toModel().validate()
    }
  }
}
