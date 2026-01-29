import AuthClient
import DatabaseClient
import Dependencies
import Foundation
import HTMLSnapshotTesting
import Logging
import ManualDClient
import ManualDCore
import ProjectClient
import SnapshotTesting
import Testing
import ViewController

@Suite(.snapshots(record: .failed))
struct ViewControllerTests {

  @Test
  func login() async throws {
    try await withDependencies {
      $0.viewController = .liveValue
      $0.auth = .failing
    } operation: {
      @Dependency(\.viewController) var viewController

      let login = try await viewController.view(.test(.login(.index())))
      assertSnapshot(of: login, as: .html)
    }
  }

  @Test
  func signup() async throws {
    try await withDependencies {
      $0.viewController = .liveValue
      $0.auth = .failing
    } operation: {
      @Dependency(\.viewController) var viewController

      let signup = try await viewController.view(.test(.login(.index())))
      assertSnapshot(of: signup, as: .html)
    }
  }

  @Test
  func userProfile() async throws {
    try await withDefaultDependencies {
      @Dependency(\.viewController) var viewController
      let html = try await viewController.view(.test(.user(.profile(.index))))
      assertSnapshot(of: html, as: .html)
    }
  }

  @Test
  func projectIndex() async throws {
    let project = withDependencies {
      $0.uuid = .incrementing
      $0.date = .constant(.mock)
    } operation: {
      Project.mock
    }

    try await withDefaultDependencies {
      $0.database.projects.fetch = { _, _ in
        .init(items: [project], metadata: .init(page: 1, per: 25, total: 1))
      }
    } operation: {
      @Dependency(\.viewController) var viewController
      let html = try await viewController.view(.test(.project(.index)))
      assertSnapshot(of: html, as: .html)
    }
  }

  @Test
  func projectDetail() async throws {

    let (
      project,
      rooms,
      equipment,
      tels,
      componentLosses,
      trunks
    ) = withDependencies {
      $0.uuid = .incrementing
      $0.date = .constant(.mock)
    } operation: {
      let project = Project.mock
      let rooms = Room.mock(projectID: project.id)
      let equipment = EquipmentInfo.mock(projectID: project.id)
      let tels = EquivalentLength.mock(projectID: project.id)
      let componentLosses = ComponentPressureLoss.mock(projectID: project.id)
      let trunks = TrunkSize.mock(projectID: project.id, rooms: rooms)

      return (
        project,
        rooms,
        equipment,
        tels,
        componentLosses,
        trunks
      )
    }

    try await withDefaultDependencies {
      $0.database.projects.get = { _ in project }
      $0.database.projects.getCompletedSteps = { _ in
        .init(equipmentInfo: true, rooms: true, equivalentLength: true, frictionRate: true)
      }
      $0.database.projects.getSensibleHeatRatio = { _ in 0.83 }
      $0.database.rooms.fetch = { _ in rooms }
      $0.database.equipment.fetch = { _ in equipment }
      $0.database.equivalentLengths.fetch = { _ in tels }
      $0.database.equivalentLengths.fetchMax = { _ in
        .init(supply: tels.first, return: tels.last)
      }
      $0.database.componentLosses.fetch = { _ in componentLosses }
      $0.projectClient.calculateDuctSizes = { _ in
        .mock(equipmentInfo: equipment, rooms: rooms, trunks: trunks)
      }
    } operation: {
      @Dependency(\.viewController) var viewController

      var html = try await viewController.view(.test(.project(.detail(project.id, .index))))
      assertSnapshot(of: html, as: .html)

      html = try await viewController.view(.test(.project(.detail(project.id, .rooms(.index)))))
      assertSnapshot(of: html, as: .html)

      html = try await viewController.view(.test(.project(.detail(project.id, .equipment(.index)))))
      assertSnapshot(of: html, as: .html)

      html = try await viewController.view(
        .test(.project(.detail(project.id, .equivalentLength(.index)))))
      assertSnapshot(of: html, as: .html)

      html = try await viewController.view(
        .test(.project(.detail(project.id, .frictionRate(.index)))))
      assertSnapshot(of: html, as: .html)

      html = try await viewController.view(
        .test(.project(.detail(project.id, .ductSizing(.index)))))
      assertSnapshot(of: html, as: .html)
    }
  }

  func createUserDependencies() -> (User, User.Profile) {
    withDependencies {
      $0.uuid = .incrementing
      $0.date = .constant(.mock)
    } operation: {
      let user = User.mock
      let profile = User.Profile.mock(userID: user.id)
      return (user, profile)
    }
  }

  @discardableResult
  func withDefaultDependencies<R>(
    isolation: isolated (any Actor)? = #isolation,
    _ updateDependencies: (inout DependencyValues) async throws -> Void = { _ in },
    operation: () async throws -> R
  ) async rethrows -> R {
    let (user, profile) = createUserDependencies()

    return try await withDependencies {
      $0.viewController = .liveValue
      $0.auth.currentUser = { user }
      $0.database.userProfiles.fetch = { _ in profile }
      $0.manualD = .liveValue
      try await updateDependencies(&$0)
    } operation: {
      try await operation()
    }
  }
}

extension Date {
  static let mock = Self(timeIntervalSince1970: 1_234_567_890)
}

extension ViewController.Request {

  static func test(
    _ route: SiteRoute.View,
    isHtmxRequest: Bool = false,
    logger: Logger = .init(label: "ViewControllerTests")
  ) -> Self {
    .init(route: route, isHtmxRequest: isHtmxRequest, logger: logger)
  }
}

extension AuthClient {
  static let failing = Self(
    createAndLogin: { _ in
      throw TestError()
    },
    currentUser: {
      throw TestError()
    },
    login: { _ in
      throw TestError()
    },
    logout: {
      throw TestError()
    }
  )
}

struct TestError: Error {}
