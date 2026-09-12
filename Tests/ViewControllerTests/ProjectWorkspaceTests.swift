import Dependencies
import Elementary
import Fluent
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Styleguide
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct ProjectWorkspaceTests {
  private let projectID = UUID(1)
  private let date = Date(timeIntervalSince1970: 1_709_251_200)

  private func path(_ index: Int, type: EquivalentLength.EffectiveLengthType = .supply)
    -> EquivalentLength
  {
    .init(
      id: UUID(index + 10), projectID: projectID, name: "Path \(index)", type: type,
      straightLengths: [20, 35],
      groups: [
        .init(group: 8, letter: "A", value: 12.5, quantity: 2),
        .init(group: 1, letter: "B", value: 35),
      ], createdAt: date, updatedAt: date)
  }

  @Test func manyPathsWithTiesAndQuantities() {
    let paths = (0..<6).map { path($0, type: $0 < 3 ? .return : .supply) }
    let view = EffectiveLengthsView(effectiveLengths: paths).environment(
      ProjectViewValue.$projectID, projectID)
    let html = view.render()
    #expect(html.components(separatedBy: "data-select-path=").count - 1 == 2)
    #expect(html.contains("<details class=\"project-panel path-canvas\" open"))
    #expect(html.contains("aria-label=\"Add supply path\""))
    #expect(html.contains("aria-label=\"Add return path\""))
    #expect(html.components(separatedBy: "top:75%").count - 1 == 2)
    #expect(html.components(separatedBy: "data-record=").count - 1 == 6)
    #expect(html.contains(">12.5</span>"))
    #expect(html.contains("ft × 2"))
    #expect(html.contains(">25</span>"))
    #expect(EffectiveLengthsView.ranked(paths.reversed()).map(\.id) == paths.map(\.id))
    assertSnapshot(of: view, as: .html)
  }

  @Test func emptyPathsAndMissingPressure() {
    assertSnapshot(
      of: EffectiveLengthsView(effectiveLengths: []).environment(
        ProjectViewValue.$projectID, projectID), as: .html)
    let losses: [ComponentPressureLoss] = [
      .init(
        id: UUID(2), projectID: projectID, name: "Filter", value: 0.1, createdAt: date,
        updatedAt: date)
    ]
    let view = FrictionRateView(
      componentLosses: losses, equivalentLengths: .init(), frictionRate: nil, blowerStatic: 0
    )
    .environment(ProjectViewValue.$projectID, projectID)
    let html = view.render()
    #expect(!html.contains("nan") && !html.contains("inf%"))
    #expect(html.contains("Blower static not set"))
    #expect(!html.contains("Available for ductwork"))
    assertSnapshot(of: view, as: .html)
  }

  @Test(arguments: [EquivalentLength.EffectiveLengthType.supply, .return])
  func pathNetworkOffersBothTypes(existingType: EquivalentLength.EffectiveLengthType) {
    let view = EffectiveLengthsView(effectiveLengths: [path(0, type: existingType)])
      .environment(ProjectViewValue.$projectID, projectID)
    let missingType: EquivalentLength.EffectiveLengthType =
      existingType == .supply ? .return : .supply
    let html = view.render()
    #expect(html.contains("aria-label=\"Add \(missingType.rawValue) path\""))
    #expect(html.contains("aria-label=\"Add \(existingType.rawValue) path\""))
    #expect(html.components(separatedBy: "data-select-path=").count - 1 == 1)
    #expect(html.contains("editor?type=\(missingType.rawValue)"))
    assertSnapshot(of: view, as: .html, named: existingType.rawValue)
  }

  @Test func emptyProjectDirectoryAndSearch() {
    let view = ProjectsTable(
      userID: UUID(2), projects: .init(items: [], metadata: .init(page: 1, per: 25, total: 0)))
    #expect(view.render().contains("Add Project"))
    #expect(view.render().contains("data-open-dialog=\"projectForm\""))
    assertSnapshot(of: view, as: .html)
    assertSnapshot(
      of: ProjectsTable(
        userID: UUID(2), projects: .init(items: [], metadata: .init(page: 1, per: 25, total: 0)),
        query: "Missing house"), as: .html)
  }

  @Test func emptyComponentLossTable() {
    let view = FrictionRateView(
      componentLosses: [], equivalentLengths: .init(), frictionRate: nil, blowerStatic: nil
    )
    .environment(ProjectViewValue.$projectID, projectID)
    let html = view.render()
    #expect(html.contains("Add a component to enter its pressure loss."))
    #expect(html.contains("data-expansion=\"pressure-flow\""))
    #expect(!html.contains("SELECTED LOSS"))
    assertSnapshot(of: view, as: .html)
  }

  @Test func equipmentWithoutSavedValues() {
    assertSnapshot(
      of: EquipmentInfoView(equipmentInfo: nil, projectID: projectID)
        .environment(ProjectViewValue.$projectID, projectID), as: .html)
  }

  @Test func projectPaginationReturnsOnlyRows() async throws {
    let html = try await ViewControllerTests().withDefaultDependencies {
      $0.database.projects.fetch = { _, _ in
        .init(items: [], metadata: .init(page: 2, per: 25, total: 30))
      }
    } operation: {
      await SiteRoute.View.ProjectRoute.page(.init(page: 2, per: 25)).renderView(
        on: .test(.project(.page(.init(page: 2, per: 25))))
      ).render()
    }
    #expect(!html.contains("<table") && !html.contains("navbar") && !html.contains("<html"))
  }

  @Test func oddTrunksStayInSeparateColumns() {
    let size = DuctSizes.SizeContainer(
      designCFM: .heating(400), roundSize: 9.8, finalSize: 10, velocity: 700, flexSize: 11,
      height: 8, width: 12)
    let trunks: [DuctSizes.TrunkContainer] = (0..<5).map { index in
      .init(
        trunk: .init(
          id: UUID(index + 20), projectID: projectID, type: index % 2 == 0 ? .supply : .return,
          rooms: [], height: 8, name: "Trunk \(index)"), ductSize: size)
    }
    let view = DuctSizingView.TrunkTable(ductSizes: .init(rooms: [], trunks: trunks)).environment(
      ProjectViewValue.$projectID, projectID)
    #expect(view.render().contains("Supply · 3"))
    #expect(view.render().contains("Return · 2"))
    assertSnapshot(of: view, as: .html)
  }
  @Test func invalidFrictionRateIsVisibleBesideTheSummaryValue() {
    for (name, rate) in [
      ("negative", -0.018), ("low", 0.02), ("high", 0.18), ("nonfinite", Double.infinity),
    ] {
      let view = FrictionRateView(
        componentLosses: [], equivalentLengths: .init(),
        frictionRate: .init(availableStaticPressure: rate < 0 ? -0.07 : 0.20, value: rate),
        blowerStatic: 0.30
      )
      .environment(ProjectViewValue.$projectID, projectID)
      let html = view.render()
      #expect(html.contains("invalid-metric"))
      let warning = html.range(of: "role=\"alert\"")!
      #expect(warning.lowerBound < html.range(of: "PRESSURE FLOW")!.lowerBound)
      assertSnapshot(of: view, as: .html, named: name)
    }
  }

}
