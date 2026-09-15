import App
import Dependencies
import DependenciesTestSupport
import Fluent
import Foundation
import ManualDCore
import SQLKit
import Testing
import Vapor

@testable import DatabaseClient

@Suite
struct TrunkSizeTests {

  @Test(.dependencies { $0.uuid = .incrementing })
  func trunkWritesPreserveProjectTimestamp() async throws {
    let app = try await Application.make(.testing)
    app.logger.logLevel = .critical
    do {
      try await configure(app, in: .live())
      try await app.autoMigrate()
      let database = DatabaseClient.live(database: app.db)
      let sql = try #require(app.db as? any SQLDatabase)
      let user = try await database.users.create(
        .init(
          email: "trunks@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let project = try await database.projects.create(user.id, .mock)
      // A fixed past timestamp catches accidental writes regardless of clock precision.
      try await sql.raw(
        """
        UPDATE project SET "updatedAt" = '2000-01-01T00:00:00Z' WHERE id = \(bind: project.id)
        """
      ).run()
      let original = try #require(try await database.projects.get(project.id))
      let trunk = try await database.trunkSizes.create(
        .init(projectID: project.id, type: .supply, rooms: [:], height: 8, name: "Main trunk"))
      #expect(try await database.projects.get(project.id) == original)
      _ = try await database.trunkSizes.update(trunk.id, .init(height: 10, name: "Supply trunk"))
      #expect(try await database.projects.get(project.id) == original)
      _ = try await database.trunkSizes.update(trunk.id, .init(height: 10, name: "Supply trunk"))
      #expect(try await database.projects.get(project.id) == original)
      try await app.autoRevert()
      try await app.asyncShutdown()
    } catch {
      try? await app.autoRevert()
      try? await app.asyncShutdown()
      throw error
    }
  }

  @Test
  func happyPath() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database) var database

      let room = try await database.rooms.create(
        project.id,
        .init(
          name: "Test", heatingLoad: 12345, coolingTotal: 12345,
          coolingSensible: nil, registerCount: 5
        )
      )

      let trunk = try await database.trunkSizes.create(
        .init(
          projectID: project.id,
          type: .supply,
          rooms: [room.id: [1, 2, 3]],
          height: 8,
          name: "Test Trunk"
        )
      )

      let fetched = try await database.trunkSizes.fetch(project.id)
      #expect(fetched == [trunk])

      let got = try await database.trunkSizes.get(trunk.id)
      #expect(got == trunk)

      let updated = try await database.trunkSizes.update(
        trunk.id, .init(type: .return)
      )
      #expect(updated.type == .return)
      #expect(updated.id == trunk.id)

      try await database.trunkSizes.delete(trunk.id)
    }
  }

  @Test
  func duplicateNamesRequireRenaming() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database) var database
      let room = try await database.rooms.create(
        project.id,
        .init(name: "Living room", heatingLoad: 1000, coolingTotal: 800, registerCount: 2))
      let trunk = try await database.trunkSizes.create(
        .init(
          projectID: project.id, type: .supply, rooms: [room.id: [1]], height: 8,
          name: "Main trunk"))

      for name in ["Main trunk", "main TRUNK", "  Main trunk\n"] {
        for type in TrunkSize.TrunkType.allCases {
          await #expect(throws: ValidationError.self) {
            try await database.trunkSizes.create(
              .init(
                projectID: project.id, type: type, rooms: [room.id: [2]], height: 10,
                name: name))
          }
        }
      }
      #expect(try await database.trunkSizes.fetch(project.id) == [trunk])

      let other = try await database.trunkSizes.create(
        .init(
          projectID: project.id, type: .return, rooms: [room.id: [2]], height: 10,
          name: "Other trunk"))
      for name in ["Main trunk", "main TRUNK", "  Main trunk\n"] {
        await #expect(throws: ValidationError.self) {
          try await database.trunkSizes.update(
            other.id, .init(type: .supply, rooms: [room.id: [1]], height: 12, name: name))
        }
        #expect(try await database.trunkSizes.get(other.id) == other)
      }

      let resized = try await database.trunkSizes.update(
        trunk.id, .init(height: 12, name: "Main trunk"))
      #expect(resized.height == 12)
      #expect(resized.name == trunk.name)
      let renamed = try await database.trunkSizes.update(other.id, .init(name: "Return trunk"))
      #expect(renamed.name == "Return trunk")
      try await database.trunkSizes.delete(trunk.id)
      let reused = try await database.trunkSizes.update(other.id, .init(name: "Main trunk"))
      #expect(reused.name == "Main trunk")
    }
  }

  @Test
  func namesAreScopedToProjectsAndUnnamedTrunksRemainSupported() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var database
      let otherProject = try await database.projects.create(
        user.id,
        .init(
          name: "Other project", streetAddress: "1 Main", city: "Monroe", state: "OH",
          zipCode: "45050"))
      for projectID in [project.id, otherProject.id] {
        _ = try await database.trunkSizes.create(
          .init(projectID: projectID, type: .supply, rooms: [:], name: "Main trunk"))
        for _ in 0..<2 {
          _ = try await database.trunkSizes.create(
            .init(projectID: projectID, type: .supply, rooms: [:]))
        }
        #expect(try await database.trunkSizes.fetch(projectID).count == 3)
      }
    }
  }

  @Test
  func notFound() async throws {
    try await withTestUserAndProject { _, project in
      @Dependency(\.database.trunkSizes) var trunks

      await #expect(throws: NotFoundError.self) {
        try await trunks.create(
          .init(projectID: project.id, type: .supply, rooms: [UUID(0): [1]])
        )
      }

      await #expect(throws: NotFoundError.self) {
        try await trunks.delete(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await trunks.update(UUID(0), .init(type: .return))
      }
    }
  }

  @Test(
    arguments: [
      TrunkModel(projectID: UUID(0), type: .return, height: 8, name: ""),
      TrunkModel(projectID: UUID(0), type: .return, height: -8, name: "Test"),
    ]
  )
  func validations(model: TrunkModel) {
    #expect(throws: (any Error).self) {
      try model.validate()
    }
  }

  @Test(
    arguments: [
      TrunkRoomModel(trunkID: UUID(0), roomID: UUID(0), registers: [-1, 1], type: .return),
      TrunkRoomModel(trunkID: UUID(0), roomID: UUID(0), registers: [1, -1], type: .return),
      TrunkRoomModel(trunkID: UUID(0), roomID: UUID(0), registers: [], type: .return),
    ]
  )
  func trunkRoomModelValidations(model: TrunkRoomModel) {
    #expect(throws: (any Error).self) {
      try model.validate()
    }
  }
}
