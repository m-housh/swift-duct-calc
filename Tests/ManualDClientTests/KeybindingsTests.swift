import ManualDCore
import Testing

struct KeybindingsTests {
  @Test func defaultsAndOverrides() throws {
    #expect(try Keybindings().validated() == Keybindings())
    let bindings = try Keybindings(overrides: [
      "projects": "Control+Shift+P", "rooms": "Control+Alt+2",
    ]).validated()
    #expect(bindings.overrides == ["projects": "Control+Shift+P"])
    #expect(bindings[.search] == "Control+K")
    #expect(bindings[.importLoads] == "Control+Alt+I")
    #expect(bindings[.reveal] == "Control+Alt+/")
    #expect(bindings[.help] == "Control+Alt+Shift+/")
  }
  @Test func contextualConflicts() throws {
    #expect(throws: KeybindingError.self) {
      try Keybindings(overrides: ["projects": "Control+Alt+2"]).validated()
    }
    #expect(throws: KeybindingError.self) {
      try Keybindings(overrides: ["search": "Control+Alt+Shift+/"]).validated()
    }
    #expect(throws: KeybindingError.self) {
      try Keybindings(overrides: ["reveal": "Control+Alt+Shift+/"]).validated()
    }
    _ = try Keybindings(overrides: ["help": "Control+Shift+/", "search": "Control+/"]).validated()
    _ = try Keybindings(overrides: [
      "nextRoom": "Control+Shift+J", "nextFitting": "Control+Shift+J",
    ]).validated()
  }
  @Test func fittingDirectionsRespectTemplateContext() throws {
    for binding in ["Control+Alt+J", "Control+Alt+Enter", "Control+Alt+A", "Control+Alt+P"] {
      #expect(throws: KeybindingError.self) {
        try Keybindings(overrides: ["fittingLeft": binding]).validated()
      }
    }
    let bindings = try Keybindings(overrides: ["fittingRight": "Control+Shift+L"]).validated()
    #expect(bindings[.fittingLeft] == "Control+Alt+H")
    #expect(bindings[.fittingDown] == "Control+Alt+J")
    #expect(bindings[.fittingUp] == "Control+Alt+K")
    #expect(bindings[.fittingRight] == "Control+Shift+L")
    // Room rows and reference fittings are separate from the guided path's card grid.
    _ = try Keybindings(overrides: ["fittingDown": "Control+Shift+J", "nextRoom": "Control+Shift+J",
      "nextFitting": "Control+Shift+J"]).validated()
  }
  @Test func pathShortcutsRespectPageContexts() throws {
    #expect(try Keybindings().validated()[.addSupply] == "Control+Alt+S")
    #expect(Keybindings()[.pressure] == "Control+Alt+S")
    for override in [
      ["addReturn": "Control+Alt+S"], ["addSupply": "Control+Alt+P"],
      ["addReturn": "Control+Alt+4"], ["addSupply": "Control+Alt+A"],
    ] {
      #expect(throws: KeybindingError.self) { try Keybindings(overrides: override).validated() }
    }
  }
  @Test func exportShortcutRespectsPageContexts() throws {
    #expect(Keybindings()[.exportPDF] == "Control+Alt+E")
    for binding in ["Control+Alt+A", "Control+Alt+P", "Control+K", "Control+Alt+6"] {
      #expect(throws: KeybindingError.self) {
        try Keybindings(overrides: ["exportPDF": binding]).validated()
      }
    }
    _ = try Keybindings(overrides: ["exportPDF": "Control+Alt+H"]).validated()
  }
  @Test(arguments: [
    "P", "Shift+P", "Control+Control+P", "Alt+Control+P", "Control+Escape", "Control+Tab",
    "Control+", "Control+F13", "Control+evil",
  ])
  func invalidCombinations(binding: String) {
    #expect(!Keybindings.isValid(binding))
    #expect(throws: KeybindingError.self) {
      try Keybindings(overrides: ["projects": binding]).validated()
    }
  }
  @Test func unknownAction() {
    #expect(throws: KeybindingError.self) {
      try Keybindings(overrides: ["unknown": "Control+P"]).validated()
    }
  }
}
