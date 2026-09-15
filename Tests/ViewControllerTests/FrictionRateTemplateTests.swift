import Dependencies
import Elementary
import Foundation
import HTMLSnapshotTesting
import ManualDClient
import ManualDCore
import SnapshotTesting
import Testing

@testable import ProjectClient
@testable import ViewController

@Suite(.snapshots(record: .failed))
struct FrictionRateTemplateViewTests {
  @Test(arguments: [false, true])
  func calculationRequiresComponentLosses(hasComponents: Bool) async throws {
    let details = withDependencies {
      $0.uuid = .incrementing
      $0.date = .constant(.mock)
    } operation: {
      let project = Project.mock
      return Project.Detail(
        project: project,
        componentLosses: hasComponents ? ComponentPressureLoss.mock(projectID: project.id) : [],
        equipmentInfo: EquipmentInfo.mock(projectID: project.id),
        equivalentLengths: EquivalentLength.mock(projectID: project.id), rooms: [], trunks: [])
    }
    #expect(details.maxContainer.totalEquivalentLength != nil)
    let manualD = ManualDClient.liveValue
    let rate = try await manualD.frictionRate(
      equipmentInfo: details.equipmentInfo, componentLosses: details.componentLosses,
      effectiveLength: details.maxContainer)
    #expect((rate != nil) == hasComponents)
    #expect(try await manualD.frictionRate(details: details) == rate)
    let view = FrictionRateView(
      componentLosses: details.componentLosses, equivalentLengths: details.maxContainer,
      frictionRate: rate, blowerStatic: details.equipmentInfo?.staticPressure
    ).environment(ProjectViewValue.$projectID, details.project.id)
    assertSnapshot(of: view, as: .html, named: hasComponents ? "configured" : "awaiting-losses")
  }

  @Test(arguments: [false, true])
  func chooser(hasComponents: Bool) {
    let view = FrictionRateTemplatesView(projectID: UUID(1), hasComponents: hasComponents)
    let html = view.render()
    #expect(html.contains("replaces all current component losses") == hasComponents)
    #expect(html.contains("/friction-rate/templates/shared"))
    #expect(html.contains("/friction-rate/templates/furnace"))
    #expect(html.contains("/friction-rate/templates/air-handler"))
    for key in ["D", "F", "A"] {
      let keycap = "<kbd class=\"kbd kbd-sm\">Ctrl+Alt+\(key)</kbd>"
      #expect(html.contains(keycap))
      #expect(view.renderFormatted().contains(keycap))
    }
    assertSnapshot(of: view, as: .html, named: hasComponents ? "existing" : "empty")
  }
}
