import Dependencies
import Fluent
import FluentSQLiteDriver
import ManualDCore
import Testing
import Vapor

@testable import DatabaseClient

@Suite
struct ProjectTests {

  @Test
  func importsProjectAndRoomsAtomically() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database
      let report = Project.PDFImport(
        project: .mock,
        rooms: [
          .init(name: "Dining", heatingLoad: 3846, coolingTotal: 1668),
          .init(name: "Kitchen", heatingLoad: 3821, coolingTotal: 4085),
        ])
      let project = try await database.projects.importPDF(user.id, report, false)
      #expect(project.sensibleHeatRatio == report.project.sensibleHeatRatio)
      #expect(project.streetAddress == report.project.streetAddress)
      let rooms = try await database.rooms.fetch(project.id)
      #expect(rooms.count == 2)
      #expect(rooms.allSatisfy { $0.registerCount == 1 && $0.delegatedTo == nil })
      #expect(try await !database.componentLosses.fetch(project.id).isEmpty)
      let steps = try await database.projects.getCompletedSteps(project.id)
      #expect(steps.rooms && steps.frictionRate && !steps.equipmentInfo && !steps.equivalentLength)
      let second = try await database.projects.importPDF(user.id, report, true)
      #expect(second.id != project.id)
      #expect(second.name == "\(project.name) (2)")
      // Fail after the first room has been saved: the project, rooms and defaults roll back.
      await #expect(throws: (any Error).self) {
        try await database.projects.importPDF(
          user.id,
          .init(
            project: .mock,
            rooms: [
              report.rooms[0], .init(name: "Invalid", heatingLoad: -1, coolingTotal: 200),
            ]), true)
      }
      #expect(try await database.projects.fetch(user.id, .first).items.count == 2)
      #expect(try await database.rooms.fetch(project.id).count == 2)
    }
  }

  @Test
  func duplicateImportRequiresConfirmationForNameOrAddress() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database
      let original = try await database.projects.create(user.id, .mock)
      let rooms: [Room.Create] = [.init(name: "Dining", heatingLoad: 3846, coolingTotal: 1668)]
      let sameName = Project.PDFImport(
        project: .init(
          name: "  " + original.name.uppercased() + "  ", streetAddress: "Different address",
          city: "Elsewhere", state: "OH", zipCode: "11111", sensibleHeatRatio: 0.88), rooms: rooms)
      let sameAddress = Project.PDFImport(
        project: .init(
          name: "Different duct system",
          streetAddress: "  "
            + original.streetAddress.uppercased().replacingOccurrences(of: " ", with: "  ") + "  ",
          city: original.city, state: original.state, zipCode: original.zipCode + "-1234",
          sensibleHeatRatio: 0.88), rooms: rooms)
      for report in [sameName, sameAddress] {
        do {
          _ = try await database.projects.importPDF(user.id, report, false)
          Issue.record("Expected duplicate confirmation")
        } catch let conflict as Project.ImportConflict {
          #expect(conflict.projects.map(\.id) == [original.id])
        }
        #expect(try await database.projects.fetch(user.id, .first).items.count == 1)
      }
      let another = try await database.projects.importPDF(user.id, sameAddress, true)
      #expect(another.id != original.id)
      #expect(try await database.projects.get(original.id) == original)
      #expect(try await database.rooms.fetch(original.id).isEmpty)
      // Identical metadata owned by another user must neither warn nor be disclosed.
      let otherUser = try await database.users.create(
        .init(email: "other@example.com", password: "super-secret", confirmPassword: "super-secret")
      )
      let separate = try await database.projects.importPDF(otherUser.id, sameName, false)
      #expect(separate.name == sameName.project.name)
    }
  }

  @Test
  func projectHappyPaths() async throws {
    try await withTestUser { user in
      @Dependency(\.database.projects) var projects

      let project = try await projects.create(user.id, .mock)

      let got = try await projects.get(project.id)
      #expect(got == project)

      let page = try await projects.fetch(user.id, .init(page: 1, per: 25))
      #expect(page.items.first! == project)

      let updated = try await projects.update(project.id, .init(sensibleHeatRatio: 0.83))
      #expect(updated.sensibleHeatRatio == 0.83)
      #expect(updated.id == project.id)

      let shr = try await projects.getSensibleHeatRatio(project.id)
      #expect(shr == 0.83)

      try await projects.delete(project.id)

    }

  }

  @Test
  func notFound() async throws {
    try await withDatabase {
      @Dependency(\.database.projects) var projects

      await #expect(throws: NotFoundError.self) {
        try await projects.delete(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await projects.update(UUID(0), .init(name: "Foo"))
      }

      await #expect(throws: NotFoundError.self) {
        try await projects.getSensibleHeatRatio(UUID(0))
      }

      await #expect(throws: NotFoundError.self) {
        try await projects.getCompletedSteps(UUID(0))
      }
    }
  }

  @Test
  func completedSteps() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database

      let project = try await database.projects.create(user.id, .mock)

      var completed = try await database.projects.getCompletedSteps(project.id)
      #expect(completed.equipmentInfo == false)
      #expect(completed.equivalentLength == false)
      #expect(completed.frictionRate == false)
      #expect(completed.rooms == false)

      _ = try await database.equipment.create(
        .init(projectID: project.id, heatingCFM: 1000, coolingCFM: 1000)
      )
      completed = try await database.projects.getCompletedSteps(project.id)
      #expect(completed.equipmentInfo == true)

      _ = try await database.componentLosses.create(
        .init(projectID: project.id, name: "Test", value: 0.2)
      )
      completed = try await database.projects.getCompletedSteps(project.id)
      #expect(completed.frictionRate == true)

      _ = try await database.rooms.create(
        project.id,
        .init(name: "Test", heatingLoad: 12345, coolingTotal: 12345)
      )
      completed = try await database.projects.getCompletedSteps(project.id)
      #expect(completed.rooms == true)

      _ = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Supply", type: .supply, straightLengths: [1], groups: [])
      )
      completed = try await database.projects.getCompletedSteps(project.id)
      // Should not be complete until we have both return and supply for a project.
      #expect(completed.equivalentLength == false)

      _ = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Return", type: .return, straightLengths: [1], groups: [])
      )
      completed = try await database.projects.getCompletedSteps(project.id)
      #expect(completed.equipmentInfo == true)
      #expect(completed.equivalentLength == true)
      #expect(completed.frictionRate == true)
      #expect(completed.rooms == true)

    }
  }

  @Test
  func detail() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var database
      let project = try await database.projects.create(user.id, .mock)

      var detail = try await database.projects.detail(project.id)
      #expect(detail?.project == project)
      #expect(detail?.equipmentInfo == nil)
      #expect(try await database.projects.detail(UUID(999)) == nil)

      let equipment = try await database.equipment.create(
        .init(projectID: project.id, heatingCFM: 1000, coolingCFM: 1000)
      )
      detail = try await database.projects.detail(project.id)
      #expect(detail != nil)

      let componentLoss = try await database.componentLosses.create(
        .init(projectID: project.id, name: "Test", value: 0.2)
      )
      let room = try await database.rooms.create(
        project.id,
        .init(name: "Test", heatingLoad: 12345, coolingTotal: 12345)
      )
      let supplyLength = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Supply", type: .supply, straightLengths: [1], groups: [])
      )
      let returnLength = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Return", type: .return, straightLengths: [1], groups: [])
      )
      detail = try await database.projects.detail(project.id)
      #expect(detail?.componentLosses == [componentLoss])
      #expect(detail?.equipmentInfo == equipment)
      #expect(detail?.rooms == [room])
      #expect(detail?.equivalentLengths.contains(supplyLength) == true)
      #expect(detail?.equivalentLengths.contains(returnLength) == true)

    }
  }

  @Test(
    arguments: [
      ProjectModel(
        name: "", streetAddress: "1234 Sesame St", city: "Nowhere", state: "OH", zipCode: "55555",
        sensibleHeatRatio: nil, userID: UUID(0)
      ),
      ProjectModel(
        name: "Testy", streetAddress: "", city: "Nowhere", state: "OH", zipCode: "55555",
        sensibleHeatRatio: nil, userID: UUID(0)
      ),
      ProjectModel(
        name: "Testy", streetAddress: "1234 Sesame St", city: "", state: "OH", zipCode: "55555",
        sensibleHeatRatio: nil, userID: UUID(0)
      ),
      ProjectModel(
        name: "Testy", streetAddress: "1234 Sesame St", city: "Nowhere", state: "",
        zipCode: "55555",
        sensibleHeatRatio: nil, userID: UUID(0)
      ),
      ProjectModel(
        name: "Testy", streetAddress: "1234 Sesame St", city: "Nowhere", state: "OH",
        zipCode: "",
        sensibleHeatRatio: nil, userID: UUID(0)
      ),
      ProjectModel(
        name: "Testy", streetAddress: "1234 Sesame St", city: "Nowhere", state: "OH",
        zipCode: "55555",
        sensibleHeatRatio: -1, userID: UUID(0)
      ),
      ProjectModel(
        name: "Testy", streetAddress: "1234 Sesame St", city: "Nowhere", state: "OH",
        zipCode: "55555",
        sensibleHeatRatio: 1.1, userID: UUID(0)
      ),
    ]
  )
  func validations(model: ProjectModel) {
    var errors = [String]()

    #expect(throws: (any Error).self) {
      do {
        try model.validate()
      } catch {
        // Just checking to make sure I'm not testing the same error over and over /
        // making sure I've reset to good values / only testing one property at a time.
        #expect(!errors.contains("\(error)"))
        errors.append("\(error)")
        throw error
      }
    }
  }
}
