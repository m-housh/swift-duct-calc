import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct DustFreeFilterTests {
  @Test func publishedTablesAndInterpolation() throws {
    let threeTon = try #require(AirFilter.defaults.first { $0.id == "dust-free-08611" })
    let fiveTon = try #require(AirFilter.defaults.first { $0.id == "dust-free-08610" })
    for (filter, airflows, drops) in [
      (threeTon, [300, 600, 900, 1200, 1350, 1500], [0.02, 0.04, 0.08, 0.13, 0.15, 0.18]),
      (fiveTon, [400, 800, 1200, 1600, 2000, 2200], [0.02, 0.05, 0.09, 0.13, 0.18, 0.22]),
    ] {
      #expect(try filter.validated() == filter)
      #expect(filter.manufacturer == "Dust Free")
      #expect(filter.description == "MERV 16")
      #expect(!filter.isEdited)
      #expect(filter.points.map(\.airflow) == airflows)
      #expect(filter.points.map(\.pressureDrop) == drops)
      for (airflow, drop) in zip(airflows, drops) {
        #expect(filter.pressureDrop(at: airflow) == drop)
      }
    }
    #expect(Set(AirFilter.defaults.map(\.id)).count == AirFilter.defaults.count)
    #expect(Set(AirFilter.defaults.compactMap(\.source)).count == AirFilter.defaults.count)
    #expect(threeTon.maxCFM == 1500)
    #expect(fiveTon.maxCFM == 2200)
    #expect(threeTon.pressureDrop(at: 1275) == 0.14)
    #expect(threeTon.pressureDrop(at: 1425) == 0.17)
    #expect(threeTon.pressureDrop(at: 1650) == 0.21)
    #expect(fiveTon.pressureDrop(at: 2100) == 0.20)
    #expect(fiveTon.additionalPressureDrop(at: 2000, allowance: 0.05) == 0.13)
    let library = FilterLibrary(favorites: [threeTon.id, fiveTon.id])
    #expect(library.suggestion(at: 1500)?.id == threeTon.id)
    #expect(library.suggestion(at: 1501)?.id == fiveTon.id)
    #expect(library.suggestion(at: 2201) == nil)
  }

  @Test func existingLibraryCanAddAndResetDustFreeCharts() throws {
    let original = FilterLibrary(
      filters: AirFilter.defaults.filter { $0.manufacturer == "Aprilaire" },
      favorites: ["213"], maximumPressureDrop: 0.20, airflowCutoffs: ["213": 1200])
    var library = try JSONDecoder().decode(
      FilterLibrary.self, from: JSONEncoder().encode(original))
    #expect(library == original)
    let view = FilterAccountView(library: library, query: .init(q: "Dust Free"))
    #expect(view.render().contains("Restore default filters"))
    #expect(view.render().contains("Dust Free Sixteen 3-ton"))
    assertSnapshot(of: view, as: .html, named: "add-to-existing-library")
    try library.apply(
      .init(
        action: .restore, revision: library.revision,
        sources: ["dust-free-08611", "dust-free-08610"]),
      newID: "unused", revision: UUID(1))
    #expect(library.filters == AirFilter.defaults)
    #expect(library.favorites == original.favorites)
    #expect(library.maximumPressureDrop == original.maximumPressureDrop)
    #expect(library.airflowCutoffs == original.airflowCutoffs)
    let index = try #require(library.filters.firstIndex { $0.id == "dust-free-08611" })
    library.filters[index].points[0].pressureDrop = 0.03
    #expect(library.filters[index].isEdited)
    try library.apply(
      .init(action: .restore, revision: library.revision, sources: ["dust-free-08611"]),
      newID: "unused", revision: UUID(2))
    #expect(library.filters == AirFilter.defaults)
  }

  @Test func lookupAndEditor() throws {
    let library = FilterLibrary(
      filters: AirFilter.defaults.filter { $0.manufacturer == "Dust Free" })
    let filter = try #require(library.filters.first)
    assertSnapshot(
      of: FilterAccountView(library: library, query: .init(q: "Dust Free")), as: .html,
      named: "library")
    assertSnapshot(
      of: FilterEditorView(library: library, filter: filter), as: .html, named: "editor")
    for airflow in [1200, 1600] {
      let view = FilterLookupResults(library: library, airflow: airflow, allowance: nil)
      let html = view.render()
      #expect(html.contains("Dust Free · MERV 16"))
      #expect(html.contains("value=\"dust-free-08611\""))
      #expect(html.contains("value=\"dust-free-08610\""))
      #expect(html.contains("Over\u{00A0}max\u{00A0}CFM") == (airflow > 1500))
      assertSnapshot(of: view, as: .html, named: "lookup-\(airflow)")
    }
  }
}
