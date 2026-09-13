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
    for key in ["D", "F", "A"] {
      let keycap = "<kbd class=\"kbd kbd-sm\">Ctrl+Alt+\(key)</kbd>"
      #expect(html.contains(keycap))
      #expect(view.renderFormatted().contains(keycap))
    }
    assertSnapshot(of: view, as: .html, named: hasComponents ? "existing" : "empty")
  }
}
