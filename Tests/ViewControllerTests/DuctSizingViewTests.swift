import DatabaseClient
import Dependencies
import Elementary
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import ProjectClient
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct DuctSizingViewTests {
  typealias Input = Project.DuctSizingUnavailable.Input

  @Test func reorderRouteSavesTheSelectedList() async throws {
    typealias Route = SiteRoute.View.ProjectRoute.DuctSizingRoute
    let ids = [UUID(30), UUID(10), UUID(20)]
    let route = Route.trunk(.reorder(.supply, ids))
    let site = SiteRoute.View.project(.detail(UUID(0), .ductSizing(route)))
    let request = try SiteRoute.View.router.request(for: site)
    #expect(request.url?.path == "/projects/\(UUID(0))/duct-sizing/trunk/order")
    #expect(try SiteRoute.View.router.match(request: request) == site)
    let saved = LockIsolated(false)
    let response = try await ViewControllerTests().withDefaultDependencies {
      $0.database.trunkSizes.reorder = { projectID, type, order in
        #expect(projectID == UUID(0))
        #expect(type == .supply)
        #expect(order == ids)
        saved.setValue(true)
      }
    } operation: {
      try await route.renderView(on: .test(site), projectID: UUID(0))
    }
    #expect(saved.value)
    #expect(response.render().isEmpty)
  }

  @Test(
    arguments: Input.allCases.map { [$0] } + [
      [.equipment, .supplyPath, .returnPath], Input.allCases,
    ])
  func missingInputsKeepNavigation(missing: [Input]) async {
    for htmx in [false, true] {
      let view = await render(
        error: Project.DuctSizingUnavailable(missingInputs: missing), htmx: htmx)
      let html = view.render()
      #expect(html.contains("aria-label=\"Project\""))
      #expect(html.contains("navbar"))
      #expect(html.contains("Complete these inputs"))
      #expect(!html.contains("Oops: Error"))
      #expect(!html.contains(">PDF<"))
      #expect(!html.contains("Add trunk / runout"))
      for input in Input.allCases {
        #expect(html.contains(input.rawValue) == missing.contains(input))
      }
      for input in missing {
        let route: SiteRoute.View.ProjectRoute.DetailRoute =
          switch input {
          case .equipment: .equipment(.index)
          case .sensibleHeatRatio, .rooms: .rooms(.index)
          case .supplyPath, .returnPath: .equivalentLength(.index)
          case .componentLosses: .frictionRate(.index)
          }
        let path = SiteRoute.View.router.path(for: .project(.detail(UUID(0), route)))
        #expect(html.contains("href=\"\(path)\""))
      }
    }
  }

  @Test func incompleteProject() async {
    let view = await render(
      error: Project.DuctSizingUnavailable(missingInputs: [.equipment, .supplyPath, .returnPath]))
    assertSnapshot(of: view, as: .html)
  }

  @Test func allInputsMissing() async {
    let view = await render(
      error: Project.DuctSizingUnavailable(missingInputs: Input.allCases))
    assertSnapshot(of: view, as: .html)
  }

  @Test func calculationFailureKeepsNavigation() async {
    let view = await render(error: ProjectClientError("Unable to calculate duct sizes."))
    #expect(view.render().contains("aria-label=\"Project\""))
    #expect(view.render().contains("Error reference"))
    assertSnapshot(of: view, as: .html)
  }

  @Test func failedStepLookupDoesNotShowPrerequisites() async {
    let view = try await ViewControllerTests().withDefaultDependencies {
      $0.database.projects.getCompletedSteps = { _ in throw NotFoundError() }
    } operation: {
      let request = ViewController.Request.test(.project(.detail(UUID(0), .ductSizing(.index))))
      do {
        return try await SiteRoute.View.ProjectRoute.DuctSizingRoute.index.renderView(
          on: request, projectID: UUID(0))
      } catch {
        return await request.errorPage(
          ViewController.present(
            error, title: "Could not load duct sizes", reference: "test-reference"))
      }
    }
    #expect(view.render().contains("Could not load duct sizes"))
    #expect(!view.render().contains("Complete these inputs"))
    #expect(!view.render().contains("aria-label=\"Project\""))
  }

  @Test func rectangularSizesSetsHeightOnEachSelectedRegister() async throws {
    typealias Route = SiteRoute.View.ProjectRoute.DuctSizingRoute
    let form = Route.RectangularSizesForm(
      height: 8,
      rooms: [
        .init(roomID: UUID(1), register: 1), .init(roomID: UUID(1), register: 2),
        .init(roomID: UUID(2), register: 1),
      ])
    let request = try SiteRoute.View.router.request(
      for: .project(.detail(UUID(0), .ductSizing(.rectangularSizes(form)))))
    #expect(request.url?.path == "/projects/\(UUID(0))/duct-sizing/rectangular-sizes")
    #expect(
      try SiteRoute.View.router.match(request: request)
        == .project(.detail(UUID(0), .ductSizing(.rectangularSizes(form)))))

    let updates = LockIsolated<[Room.ID: [Int]]>([:])
    _ = try await ViewControllerTests().withDefaultDependencies {
      $0.database.rooms.setRectangularSizes = { selection, height in
        #expect(height == 8)
        updates.setValue(selection)
      }
      $0.database.projects.getCompletedSteps = { _ in
        .init(equipmentInfo: true, rooms: true, equivalentLength: true, frictionRate: true)
      }
      $0.projectClient.calculateRoomDuctSizes = { _ in [] }
      $0.projectClient.calculateTrunkDuctSizes = { _ in [] }
    } operation: {
      try await Route.rectangularSizes(form).renderView(
        on: .test(.project(.detail(UUID(0), .ductSizing(.rectangularSizes(form))))),
        projectID: UUID(0))
    }
    #expect(updates.value == [UUID(1): [1, 2], UUID(2): [1]])
  }

  @Test func rectangularSizesShowsCurrentSizesPerRegister() {
    let sizes: [(register: Int, width: Int?, height: Int?)] = [
      (register: 1, width: 10, height: 8),
      (register: 2, width: 12, height: 6),
      (register: 3, width: nil, height: nil),
    ]
    let rooms: [DuctSizes.RoomContainer] = sizes.map { size in
      .init(
        roomID: UUID(1), roomName: "Living Room", roomLevel: nil,
        roomRegister: size.register, heatingLoad: 1_000, coolingLoad: 800,
        heatingCFM: 100, coolingCFM: 80,
        ductSize: .init(
          designCFM: .heating(100), roundSize: 7, finalSize: 8, velocity: 400, flexSize: 8,
          height: size.height, width: size.width))
    }
    let form = RectangularSizesForm(rooms: rooms)
      .environment(ProjectViewValue.$projectID, UUID(0))
    let html = form.render()
    #expect(html.components(separatedBy: "class=\"size-chip\"").count - 1 == 2)
    #expect(html.contains("<span class=\"size-chip\">10 × 8 in.</span>"))
    #expect(!html.contains("Current:"))
    #expect(!html.contains("Not set"))
    assertSnapshot(of: form, as: .html)
  }

  @Test func clearRectangularSizesOnlyDeletesSelectedRegisters() async throws {
    typealias Route = SiteRoute.View.ProjectRoute.DuctSizingRoute
    let room = Room(
      id: UUID(1), projectID: UUID(0), name: "Living Room", heatingLoad: 1_000,
      coolingLoad: .init(total: 800, sensible: nil), registerCount: 3,
      rectangularSizes: [
        .init(id: UUID(10), register: 1, height: 8),
        .init(id: UUID(11), register: 2, height: 6),
      ], createdAt: .mock, updatedAt: .mock)
    let route = Route.clearRectangularSizes([
      .init(roomID: room.id, register: 1), .init(roomID: room.id, register: 3),
    ])
    let request = try SiteRoute.View.router.request(
      for: .project(.detail(UUID(0), .ductSizing(route))))
    #expect(request.url?.path == "/projects/\(UUID(0))/duct-sizing/rectangular-sizes/clear")
    #expect(
      try SiteRoute.View.router.match(request: request)
        == .project(.detail(UUID(0), .ductSizing(route))))
    let deletions = LockIsolated<[Room.ID: [Int]]>([:])
    let response = try await ViewControllerTests().withDefaultDependencies {
      $0.database.rooms.setRectangularSizes = { selection, height in
        #expect(height == nil)
        deletions.setValue(selection)
      }
      $0.database.projects.getCompletedSteps = { _ in
        .init(equipmentInfo: true, rooms: true, equivalentLength: true, frictionRate: true)
      }
      $0.projectClient.calculateRoomDuctSizes = { _ in [] }
      $0.projectClient.calculateTrunkDuctSizes = { _ in [] }
    } operation: {
      try await route.renderView(
        on: .test(.project(.detail(UUID(0), .ductSizing(route)))), projectID: UUID(0))
    }
    #expect(deletions.value == [room.id: [1, 3]])
    #expect(response.render().contains("Branch schedule"))
  }

  @Test(arguments: [false, true])
  func individualRectangularSizeChangesRefreshBulkModal(clearing: Bool) async throws {
    typealias Route = SiteRoute.View.ProjectRoute.DuctSizingRoute
    let room = Room(
      id: UUID(1), projectID: UUID(0), name: "Living Room", heatingLoad: 1_000,
      coolingLoad: .init(total: 800, sensible: nil), createdAt: .mock, updatedAt: .mock)
    let sizes: [DuctSizes.RoomContainer] = [2, 1].map { register in
      .init(
        roomID: room.id, roomName: room.name, roomLevel: nil, roomRegister: register,
        heatingLoad: 1_000, coolingLoad: 800, heatingCFM: 100, coolingCFM: 80,
        ductSize: .init(
          rectangularID: clearing && register == 1 ? nil : UUID(register + 1),
          designCFM: .heating(100), roundSize: 7, finalSize: 8, velocity: 400, flexSize: 8,
          height: clearing && register == 1 ? nil : 8,
          width: clearing && register == 1 ? nil : 10))
    }
    let route: Route =
      clearing
      ? .deleteRectangularSize(room.id, .init(rectangularSizeID: UUID(2), register: 1))
      : .roomRectangularForm(room.id, .init(register: 1, height: 8))
    let response = try await ViewControllerTests().withDefaultDependencies {
      $0.database.rooms.updateRectangularSize = { _, _ in room }
      $0.database.rooms.clearRectangularSize = { _, _, _ in room }
      $0.projectClient.calculateRoomDuctSizes = { _ in sizes }
    } operation: {
      try await route.renderView(
        on: .test(.project(.detail(UUID(0), .ductSizing(route))), isHtmxRequest: true),
        projectID: UUID(0))
    }
    let html = response.render()
    #expect(html.contains("<tr id=\"\(DuctSizingView.RoomRow.id(sizes[1]))\""))
    let modal = String(html.split(separator: "<fieldset").last ?? "")
    #expect(modal.contains("hx-swap-oob=\"outerHTML\""))
    #expect(modal.contains("Living Room - SR.1"))
    #expect(modal.contains("Living Room - SR.2"))
    #expect(modal.components(separatedBy: "class=\"size-chip\"").count - 1 == (clearing ? 1 : 2))
    let sibling = String(html.split(separator: "<template>").last ?? "")
    #expect(sibling.contains("id=\"\(DuctSizingView.RoomRow.id(sizes[0]))\""))
    #expect(sibling.contains("hx-swap-oob=\"outerHTML\""))
    #expect(sibling.contains("name=\"id\" value=\"\(UUID(3))\""))
    #expect(!modal.contains("Not set"))
    if let first = modal.range(of: "Living Room - SR.1"),
      let second = modal.range(of: "Living Room - SR.2")
    {
      #expect(first.lowerBound < second.lowerBound)
    }
    assertSnapshot(of: response, as: .html, named: clearing ? "cleared" : "updated")
  }

  private func render(error: any Error, htmx: Bool = false) async -> AnySendableHTML {
    let missing = Set((error as? Project.DuctSizingUnavailable)?.missingInputs ?? [])
    return await ViewControllerTests().withDefaultDependencies {
      $0.uuid = .constant(UUID(0))
      $0.database.projects.getForUser = { _, _ in Project.mock }
      $0.database.projects.getCompletedSteps = { _ in
        .init(
          equipmentInfo: !missing.contains(.equipment), rooms: !missing.contains(.rooms),
          equivalentLength: !missing.contains(.supplyPath) && !missing.contains(.returnPath),
          frictionRate: !missing.contains(.componentLosses))
      }
      $0.projectClient.calculateRoomDuctSizes = { _ in throw error }
    } operation: {
      let request = ViewController.Request.test(
        .project(.detail(UUID(0), .ductSizing(.index))), isHtmxRequest: htmx)
      do {
        return try await SiteRoute.View.ProjectRoute.DuctSizingRoute.index.renderView(
          on: request, projectID: UUID(0))
      } catch {
        return await request.errorPage(
          ViewController.present(
            error, title: "Could not load duct sizes", reference: "test-reference"))
      }
    }
  }
}
