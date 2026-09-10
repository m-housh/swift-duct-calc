import DatabaseClient
import Dependencies
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
    #expect(view.render().contains("Unable to calculate duct sizes."))
    assertSnapshot(of: view, as: .html)
  }

  @Test func missingProjectDoesNotShowPrerequisites() async {
    let view = await ViewControllerTests().withDefaultDependencies {
      $0.database.projects.getCompletedSteps = { _ in throw NotFoundError() }
    } operation: {
      await SiteRoute.View.ProjectRoute.DuctSizingRoute.index.renderView(
        on: .test(.project(.detail(UUID(0), .ductSizing(.index)))), projectID: UUID(0))
    }
    #expect(view.render().contains("Oops: Error"))
    #expect(!view.render().contains("Complete these inputs"))
    #expect(!view.render().contains("aria-label=\"Project\""))
  }

  private func render(error: any Error, htmx: Bool = false) async -> AnySendableHTML {
    let missing = Set((error as? Project.DuctSizingUnavailable)?.missingInputs ?? [])
    return await ViewControllerTests().withDefaultDependencies {
      $0.database.projects.getCompletedSteps = { _ in
        .init(
          equipmentInfo: !missing.contains(.equipment), rooms: !missing.contains(.rooms),
          equivalentLength: !missing.contains(.supplyPath) && !missing.contains(.returnPath),
          frictionRate: !missing.contains(.componentLosses))
      }
      $0.projectClient.calculateRoomDuctSizes = { _ in throw error }
    } operation: {
      await SiteRoute.View.ProjectRoute.DuctSizingRoute.index.renderView(
        on: .test(.project(.detail(UUID(0), .ductSizing(.index))), isHtmxRequest: htmx),
        projectID: UUID(0))
    }
  }
}
