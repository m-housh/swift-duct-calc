import Dependencies
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct FilterLookupTests {
  @Test func pressureDropFollowsTheChart() throws {
    let filter = try #require(AprilaireFilter.named("413"))
    #expect(filter.maxCFM == 2000)
    #expect(filter.pressureDrop(at: 1000) == 0.14)
    // 1,100 CFM is halfway between 0.14 and 0.17; the result rounds up.
    #expect(filter.pressureDrop(at: 1100) == 0.16)
    #expect(filter.pressureDrop(at: 100) == 0.01)
    // Above the rating the last segment (0.31 to 0.37 per 200 CFM) continues.
    #expect(filter.pressureDrop(at: 2200) == 0.43)

    let startsAt400 = try #require(AprilaireFilter.named("216"))
    #expect(startsAt400.pressureDrop(at: 200) == 0.03)
    #expect(AprilaireFilter.named("413cbn")?.model == "413CBN")
    #expect(AprilaireFilter.named("999") == nil)
    #expect(Set(AprilaireFilter.all.map(\.model)).count == AprilaireFilter.all.count)
  }

  @Test func largerAirflowIgnoresMissingValues() {
    func equipment(heating: Int?, cooling: Int?) -> EquipmentInfo {
      .init(
        id: UUID(0), projectID: UUID(0), heatingCFM: heating, coolingCFM: cooling,
        createdAt: .mock, updatedAt: .mock)
    }
    #expect(equipment(heating: 900, cooling: 1200).largerAirflow == 1200)
    #expect(equipment(heating: 900, cooling: nil).largerAirflow == 900)
    #expect(equipment(heating: nil, cooling: nil).largerAirflow == nil)
  }

  @Test func lookupWithAirflowOffersReplacement() {
    let losses = [
      loss(1, "evaporator-coil", 0.2), loss(2, "filter", 0.1),
      loss(3, "Return filter grille", 0.05),
    ]
    let view = FilterLookupView(projectID: UUID(0), airflow: 1300, componentLosses: losses)
    let html = view.render()
    #expect(
      html.contains(
        "hx-post=\"/projects/00000000-0000-0000-0000-000000000000/friction-rate/filters\""))
    #expect(html.contains("Replace filter (0.10)"))
    #expect(!html.contains("Replace evaporator-coil"))
    // 113, 313, 110, and 310 are rated to 1,200 CFM.
    #expect(html.components(separatedBy: "Over\u{00A0}max\u{00A0}CFM").count - 1 == 4)
    assertSnapshot(of: view, as: .html, named: "airflow")
  }

  @Test func lookupWithoutAirflowPointsToEquipment() {
    let view = FilterLookupView(projectID: UUID(0), airflow: nil, componentLosses: [])
    let html = view.render()
    #expect(html.contains("/projects/00000000-0000-0000-0000-000000000000/equipment"))
    #expect(!html.contains("name=\"model\""))
    assertSnapshot(of: view, as: .html, named: "no-airflow")
  }

  private func loss(_ id: Int, _ name: String, _ value: Double) -> ComponentPressureLoss {
    .init(
      id: UUID(id), projectID: UUID(0), name: name, value: value, createdAt: .mock,
      updatedAt: .mock)
  }
}
