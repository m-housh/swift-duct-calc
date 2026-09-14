import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct FilterAccountTests {
  @Test func libraryAndPreferences() {
    var library = FilterLibrary(
      filters: Array(AirFilter.defaults.prefix(3)), favorites: ["216", "516"],
      maximumPressureDrop: 0.15)
    assertSnapshot(of: FilterAccountView(library: library), as: .html, named: "library")
    assertSnapshot(
      of: FilterAccountView(library: library, query: .init(tab: "preferences")), as: .html,
      named: "preferences")
    library.filters = []
    library.favorites = []
    library.maximumPressureDrop = nil
    assertSnapshot(of: FilterAccountView(library: library), as: .html, named: "empty")
    assertSnapshot(
      of: FilterAccountView(library: library, query: .init(tab: "preferences")), as: .html,
      named: "no-preferences")
  }
  @Test func editorsAndTemplateStep() {
    let library = FilterLibrary()
    assertSnapshot(of: FilterEditorView(library: library, filter: nil), as: .html, named: "new")
    assertSnapshot(
      of: FilterEditorView(library: library, filter: library.filters.first), as: .html,
      named: "edit")
    assertSnapshot(
      of: FilterEditorView(library: library, filter: library.filters.first, duplicate: true),
      as: .html, named: "duplicate")
    assertSnapshot(
      of: FilterLookupView(
        projectID: UUID(0), airflow: 1200, componentLosses: [],
        library: .init(
          filters: Array(AirFilter.defaults.prefix(3)), favorites: ["516"],
          maximumPressureDrop: 0.15), allowance: 0.03, template: .furnace), as: .html,
      named: "template-filter")
  }
  @Test func airflowCutoffPreferences() {
    let library = FilterLibrary(
      filters: AirFilter.defaults.filter { ["213", "513"].contains($0.id) },
      favorites: ["213", "513"], maximumPressureDrop: 0.20, airflowCutoffs: ["213": 1200])
    for airflow in [1199, 1200] {
      assertSnapshot(
        of: FilterAccountView(library: library, query: .init(tab: "preferences", airflow: airflow)),
        as: .html, named: "cutoff-\(airflow)")
    }
    let picker = FilterLookupView(
      projectID: UUID(0), airflow: 1200, componentLosses: [], library: library)
    #expect(picker.render().contains("value=\"213\""))
    assertSnapshot(of: picker, as: .html, named: "cutoff-picker")
  }
  @Test func cutoffsRespectBoundariesAndOtherLimits() throws {
    var library = FilterLibrary(
      favorites: ["213", "513"], maximumPressureDrop: 0.20, airflowCutoffs: ["213": 1200])
    let originalChart = library.filters
    #expect(library.suggestion(at: 1199)?.id == "213")
    #expect(library.suggestion(at: 1200)?.id == "513")
    #expect(library.suggestion(at: 1201)?.id == "513")
    #expect(library.suggestion(at: 0) == nil)
    #expect(library.suggestion(at: 3001) == nil)
    library.maximumPressureDrop = 0.10
    #expect(library.suggestion(at: 1199)?.id == "513")
    library.maximumPressureDrop = 0.01
    #expect(library.suggestion(at: 1199) == nil)
    library.maximumPressureDrop = 0.20
    try library.apply(
      .init(action: .cutoff, revision: library.revision, id: "213"),
      newID: "unused", revision: UUID(1))
    #expect(library.airflowCutoffs.isEmpty)
    #expect(library.suggestion(at: 1200)?.id == "213")
    #expect(library.filters == originalChart)
  }
  @Test func cutoffValidationAndFavoriteLifecycle() throws {
    var library = FilterLibrary(favorites: ["213", "513"])
    for cutoff in [-1, 0, 100001] {
      #expect(throws: FilterError.self) {
        try library.apply(
          .init(action: .cutoff, revision: library.revision, id: "213", airflowCutoff: cutoff),
          newID: "unused", revision: UUID(1))
      }
      #expect(library.airflowCutoffs.isEmpty)
    }
    for id in ["missing", "216"] {
      #expect(throws: FilterError.self) {
        try library.apply(
          .init(action: .cutoff, revision: library.revision, id: id, airflowCutoff: 1200),
          newID: "unused", revision: UUID(1))
      }
    }
    try library.apply(
      .init(action: .cutoff, revision: library.revision, id: "213", airflowCutoff: 1200),
      newID: "unused", revision: UUID(1))
    try library.apply(
      .init(action: .move, revision: library.revision, id: "213", direction: 1),
      newID: "unused", revision: UUID(2))
    #expect(library.airflowCutoffs == ["213": 1200])
    for action in [FilterLibrary.Change.Action.favorite, .delete, .save] {
      var copy = library
      try copy.apply(
        .init(
          action: action, revision: copy.revision, id: "213",
          filter: copy.filters.first { $0.id == "213" }, selected: false),
        newID: "unused", revision: UUID(3))
      #expect(copy.airflowCutoffs.isEmpty)
      #expect(!copy.favorites.contains("213"))
    }
  }
  @Test func existingSavedLibrariesHaveNoCutoffs() throws {
    let original = FilterLibrary(favorites: ["213", "513"], maximumPressureDrop: 0.20)
    var document = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    document.removeValue(forKey: "airflowCutoffs")
    let decoded = try JSONDecoder().decode(
      FilterLibrary.self, from: JSONSerialization.data(withJSONObject: document))
    #expect(decoded == original)
    #expect(decoded.suggestion(at: 1200)?.id == "213")
  }
  @Test func chartValidationAndSuggestions() throws {
    let filter = AirFilter(
      id: "custom", manufacturer: "Example", model: "Media",
      points: [.init(airflow: 400, pressureDrop: 0.015), .init(airflow: 1600, pressureDrop: 0.12)])
    #expect(try filter.validated() == filter)
    #expect(filter.pressureDrop(at: 1000) == 0.07)
    #expect(filter.pressureDrop(at: 200) == 0.01)
    #expect(filter.pressureDrop(at: 2000) == 0.16)
    var library = FilterLibrary(
      filters: [filter], favorites: [filter.id], maximumPressureDrop: 0.06)
    #expect(library.suggestion(at: 1000) == nil)
    library.maximumPressureDrop = nil
    #expect(library.suggestion(at: 1000) == filter)
    #expect(library.suggestion(at: 2000) == nil)
    for drop in [Double.nan, .infinity, -0.1, 0, 1.1] {
      var invalid = filter
      invalid.points[0].pressureDrop = drop
      #expect(throws: FilterError.self) { try invalid.validated() }
    }
    var invalid = filter
    invalid.points[1].airflow = 400
    #expect(throws: FilterError.self) { try invalid.validated() }
    #expect(
      FrictionRateTemplate.allCases.allSatisfy {
        $0.components(projectID: UUID(0)).allSatisfy { $0.name != "filter" }
      })
  }
  @Test func favoriteOrderingAndRestoreConflicts() throws {
    var library = FilterLibrary(favorites: ["213", "513"])
    try library.apply(
      .init(action: .favorite, revision: library.revision, id: "213", selected: true),
      newID: "unused", revision: UUID(1))
    #expect(library.favorites == ["213", "513"])
    try library.apply(
      .init(action: .move, revision: library.revision, id: "513", direction: -1), newID: "unused",
      revision: UUID(2))
    #expect(library.favorites == ["513", "213"])
    var custom = try #require(library.filters.first { $0.id == "213" })
    custom.id = "custom"
    custom.source = nil
    library.filters.removeAll { $0.id == "213" }
    library.filters.append(custom)
    #expect(throws: FilterError.self) {
      try library.apply(
        .init(action: .restore, revision: library.revision, sources: ["213"]), newID: "unused",
        revision: UUID(3))
    }
  }

}
