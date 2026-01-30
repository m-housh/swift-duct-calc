import DatabaseClient
import Dependencies
import Foundation
import ManualDCore
import Testing

@Suite
struct ComponentLossTests {

  @Test
  func happyPaths() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var database

      // let project = try await database.projects.create(user.id, .mock)

      let componentLoss = try await database.componentLosses.create(
        .init(projectID: project.id, name: "Test", value: 0.2)
      )

      let fetched = try await database.componentLosses.fetch(project.id)
      #expect(fetched == [componentLoss])

      let got = try await database.componentLosses.get(componentLoss.id)
      #expect(got == componentLoss)

      let updated = try await database.componentLosses.update(
        componentLoss.id, .init(name: "Updated", value: nil)
      )
      #expect(updated.id == componentLoss.id)
      #expect(updated.value == componentLoss.value)
      #expect(updated.name == "Updated")

      try await database.componentLosses.delete(componentLoss.id)

    }
  }

  @Test
  func notFound() async throws {
    try await withDatabase {
      @Dependency(\.database.componentLosses) var componentLosses

      await #expect(throws: NotFoundError.self) {
        try await componentLosses.delete(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await componentLosses.update(UUID(0), .init(name: "Updated"))
      }
    }
  }
}
