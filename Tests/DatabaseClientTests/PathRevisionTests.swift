import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

@Suite
struct PathRevisionTests {
  @Test
  func conditionalWritesRejectStaleAndLegacyWriters() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database) var database
      let saved = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Initial", type: .supply, straightLengths: [10], groups: []))
      let updated = try await database.equivalentLengths.updateIfUnchanged(
        saved, .init(name: "Newer"))
      #expect(saved.revision != updated.revision)
      await #expect(throws: PathConflictError.self) {
        try await database.equivalentLengths.updateIfUnchanged(
          saved, .init(name: "Stale", straightLengths: [25]))
      }
      #expect(try await database.equivalentLengths.get(saved.id) == updated)
      await #expect(throws: (any Error).self) {
        try await database.equivalentLengths.updateIfUnchanged(
          updated, .init(straightLengths: [-1]))
      }
      #expect(
        try await database.equivalentLengths.get(saved.id) == updated,
        "Validation failures must roll back the claimed revision as well as the data")
      let legacy = try await database.equivalentLengths.update(saved.id, .init(name: "Legacy edit"))
      #expect(legacy.revision != updated.revision)
      await #expect(throws: PathConflictError.self) {
        try await database.equivalentLengths.updateIfUnchanged(updated, .init(name: "Stale again"))
      }
      #expect(try await database.equivalentLengths.get(saved.id) == legacy)
    }
  }

  @Test
  func concurrentWritersCannotBothCommit() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database) var database
      let saved = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Initial", type: .supply, straightLengths: [], groups: []))
      let lengths = database.equivalentLengths
      let successes = await withTaskGroup(of: Bool.self) { group in
        for name in ["First", "Second"] {
          group.addTask { [lengths] in
            do {
              _ = try await lengths.updateIfUnchanged(saved, .init(name: name))
              return true
            } catch is PathConflictError { return false } catch {
              Issue.record("Unexpected concurrent save error: \(error)")
              return false
            }
          }
        }
        var count = 0
        for await succeeded in group { if succeeded { count += 1 } }
        return count
      }
      #expect(successes == 1)
      let current = try #require(try await database.equivalentLengths.get(saved.id))
      #expect(["First", "Second"].contains(current.name))
      #expect(current.revision != saved.revision)
    }
  }
}
