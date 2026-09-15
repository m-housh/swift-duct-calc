import Elementary
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct KeybindingsViewTests {
  @Test func editor() {
    assertSnapshot(of: KeybindingsView(bindings: .init()), as: .html, named: "defaults")
    let bindings = Keybindings(overrides: ["projects": "Control+Shift+P", "search": "Alt+K"])
    assertSnapshot(of: KeybindingsView(bindings: bindings), as: .html, named: "custom")
    let page = MainPage(keybindings: bindings) { KeybindingsView(bindings: bindings) }.render()
    #expect(page.contains("aria-keyshortcuts=\"Control+Shift+P\""))
    #expect(page.contains("data-keybindings="))
    #expect(page.contains("data-binding=\"Alt+K\""))
  }
}
