import Elementary
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct FrictionRateTemplateViewTests {
  @Test(arguments: [false, true])
  func chooser(hasComponents: Bool) {
    let view = FrictionRateTemplatesView(projectID: UUID(1), hasComponents: hasComponents)
    let html = view.render()
    #expect(html.contains("replaces all current component losses") == hasComponents)
    #expect(html.contains("/friction-rate/templates/shared"))
    #expect(html.contains("/friction-rate/templates/furnace"))
    #expect(html.contains("/friction-rate/templates/air-handler"))
    assertSnapshot(of: view, as: .html, named: hasComponents ? "existing" : "empty")
  }
}
