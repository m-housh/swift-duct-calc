import Dependencies
import Elementary
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct TrunkTemplateTests {
  private func rooms(withLevels: Bool, mixedBasements: Bool = false) -> [DuctSizes.RoomContainer] {
    let runs: [(Int, Int, Int?)] = [(1, 1, 1), (1, 2, 1), (2, 1, 0), (3, 1, 2), (4, 1, nil)]
      + (mixedBasements ? [(5, 1, -1), (5, 2, -1), (6, 1, -2)] : [])
    return runs.map {
      (id: Int, register: Int, level: Int?) in
      .init(
        roomID: UUID(id), roomName: "Room \(id)",
        roomLevel: withLevels ? level.map { Room.Level(rawValue: $0) } : nil,
        roomRegister: register, heatingLoad: 1_000, coolingLoad: 800,
        heatingCFM: 100, coolingCFM: 80,
        ductSize: .init(
          designCFM: .heating(100), roundSize: 7, finalSize: 8, velocity: 400, flexSize: 8))
    }
  }

  @Test(arguments: [false, true])
  func chooser(withLevels: Bool) {
    let view = TrunkSizeForm(rooms: rooms(withLevels: withLevels))
      .environment(ProjectViewValue.$projectID, UUID(0))
    let html = view.render()
    #expect(html.contains("No template"))
    #expect(html.contains("aria-expanded=\"false\""))
    #expect(html.contains("Main supply trunk"))
    #expect(html.contains("Main return trunk"))
    #expect(html.contains("Level-1 supply trunk") == withLevels)
    #expect(html.contains("Basement return trunk") == withLevels)
    assertSnapshot(of: view, as: .html, named: withLevels ? "levels" : "main")
  }

  @Test func emptyRoomsDoNotOfferTemplates() {
    let view = TrunkSizeForm(rooms: []).environment(ProjectViewValue.$projectID, UUID(0))
    #expect(!view.render().contains("data-trunk-template"))
    assertSnapshot(of: view, as: .html)
  }

  @Test func equivalentBasementLevelsShareOneTemplate() {
    let view = TrunkSizeForm(rooms: rooms(withLevels: true, mixedBasements: true))
      .environment(ProjectViewValue.$projectID, UUID(0))
    let html = view.render()
    for type in ["supply", "return"] {
      #expect(html.components(separatedBy: "aria-label=\"Basement \(type) trunk\"").count == 2)
    }
    assertSnapshot(of: view, as: .html)
  }

  @Test func editingDoesNotOfferTemplates() {
    let trunk = DuctSizes.TrunkContainer(
      trunk: .init(
        id: UUID(10), projectID: UUID(0), type: .return, rooms: [], height: 8,
        name: "Existing return"),
      ductSize: .init(
        designCFM: .heating(500), roundSize: 12, finalSize: 12, velocity: 600, flexSize: 14))
    let view = TrunkSizeForm(trunk: trunk, rooms: rooms(withLevels: true))
      .environment(ProjectViewValue.$projectID, UUID(0))
    #expect(!view.render().contains("data-trunk-template"))
    assertSnapshot(of: view, as: .html)
  }

  @Test(arguments: [TrunkSize.TrunkType.supply, .return], [nil, 8])
  func templateSelectionsUseExistingSave(type: TrunkSize.TrunkType, height: Int?) async throws {
    typealias Route = SiteRoute.View.ProjectRoute.DuctSizingRoute
    let form = Route.TrunkSizeForm(
      projectID: UUID(0), type: type, height: height, name: "Main \(type.rawValue) trunk",
      rooms: ["\(UUID(1))_1", "\(UUID(1))_2", "\(UUID(2))_1"])
    let route = Route.trunk(.submit(form))
    let siteRoute = SiteRoute.View.project(.detail(UUID(0), .ductSizing(route)))
    let request = try SiteRoute.View.router.request(for: siteRoute)
    #expect(try SiteRoute.View.router.match(request: request) == siteRoute)
    let saved = LockIsolated<TrunkSize.Create?>(nil)
    _ = try await ViewControllerTests().withDefaultDependencies {
      $0.database.trunkSizes.create = { request in
        saved.setValue(request)
        return .init(
          id: UUID(10), projectID: request.projectID, type: request.type, rooms: [],
          height: request.height, name: request.name)
      }
      $0.database.projects.getCompletedSteps = { _ in
        .init(equipmentInfo: true, rooms: true, equivalentLength: true, frictionRate: true)
      }
      $0.projectClient.calculateRoomDuctSizes = { _ in [] }
      $0.projectClient.calculateDuctSizes = { _ in .init(rooms: [], trunks: []) }
    } operation: {
      try await route.renderView(on: .test(siteRoute), projectID: UUID(0))
    }
    #expect(saved.value == .init(
      projectID: UUID(0), type: type, rooms: [UUID(1): [1, 2], UUID(2): [1]],
      height: height, name: form.name))
  }
}
