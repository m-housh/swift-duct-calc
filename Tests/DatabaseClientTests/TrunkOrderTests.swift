import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

struct TrunkOrderTests {
  @Test func appendsReordersAndKeepsProjectDetailsInOrder() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database) var database
      let first = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:], name: "First"))
      let returnTrunk = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .return, rooms: [:], name: "Return"))
      let second = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:], name: "Second"))
      #expect(
        try await database.trunkSizes.fetch(project.id).map(\.id) == [
          first.id, second.id, returnTrunk.id,
        ])

      try await database.trunkSizes.reorder(project.id, .supply, [second.id, first.id])
      _ = try await database.trunkSizes.update(second.id, .init(height: 10, name: "Renamed"))
      let third = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:], name: "Third"))
      let expected = [second.id, first.id, third.id, returnTrunk.id]
      #expect(try await database.trunkSizes.fetch(project.id).map(\.id) == expected)
      #expect(try await database.projects.detail(project.id)?.trunks.map(\.id) == expected)

      try await database.trunkSizes.delete(first.id)
      let fourth = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:], name: "Fourth"))
      #expect(
        try await database.trunkSizes.fetch(project.id).map(\.id) == [
          second.id, third.id, fourth.id, returnTrunk.id,
        ])
      _ = try await database.trunkSizes.update(second.id, .init(type: .return))
      #expect(
        try await database.trunkSizes.fetch(project.id).map(\.id) == [
          third.id, fourth.id, returnTrunk.id, second.id,
        ])
    }
  }

  @Test func rejectsIncompleteDuplicateForeignAndWrongTypeListsWithoutChangingOrder() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var database
      let otherProject = try await database.projects.create(
        user.id,
        .init(
          name: "Other project", streetAddress: "2 Main St", city: "Monroe", state: "OH",
          zipCode: "45050"))
      let first = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:]))
      let second = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:]))
      let returnTrunk = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .return, rooms: [:]))
      let foreign = try await database.trunkSizes.create(
        .init(projectID: otherProject.id, type: .supply, rooms: [:]))
      for ids in [
        [], [first.id], [second.id, second.id], [second.id, first.id, foreign.id],
        [second.id, first.id, returnTrunk.id], [second.id, UUID(999)],
      ] {
        await #expect(throws: ValidationError.self) {
          try await database.trunkSizes.reorder(project.id, .supply, ids)
        }
        #expect(
          try await database.trunkSizes.fetch(project.id).map(\.id) == [
            first.id, second.id, returnTrunk.id,
          ])
        #expect(try await database.trunkSizes.fetch(otherProject.id) == [foreign])
      }
      try await database.trunkSizes.delete(second.id)
      await #expect(throws: ValidationError.self) {
        try await database.trunkSizes.reorder(project.id, .supply, [second.id, first.id])
      }
    }
  }
}
