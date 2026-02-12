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
      #expect(detail == nil)

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
