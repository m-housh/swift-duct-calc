import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

struct FilterLibraryTests {
  @Test func dustFreeChartsCanBeRestoredAndApplied() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var db
      _ = try await db.equipment.create(
        .init(projectID: project.id, heatingCFM: 900, coolingCFM: 1200))
      var library = try await db.filters.fetch(user.id)
      library = try await db.filters.update(
        user.id,
        .init(action: .delete, revision: library.revision, id: "dust-free-08611"))
      #expect(try await db.filters.fetch(user.id) == library)
      library = try await db.filters.update(
        user.id,
        .init(action: .restore, revision: library.revision, sources: ["dust-free-08611"]))
      #expect(try await db.filters.fetch(user.id) == library)
      for (id, name, drop) in [
        ("dust-free-08611", "Dust Free Sixteen 3-ton", 0.10),
        ("dust-free-08610", "Dust Free Sixteen 5-ton", 0.06),
      ] {
        try await db.filters.apply(user.id, project.id, .init(model: id, allowance: "0.03"))
        let loss = try #require(
          try await db.componentLosses.fetch(project.id).first { $0.name.hasPrefix(name) })
        #expect(loss.name == "\(name) filter (less 0.03 in equipment rating)")
        #expect(loss.value == drop)
      }
    }
  }

  @Test func savedCutoffDoesNotRestrictManualSelection() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var db
      _ = try await db.equipment.create(
        .init(projectID: project.id, heatingCFM: 900, coolingCFM: 1200))
      var library = try await db.filters.fetch(user.id)
      library = try await db.filters.update(
        user.id, .init(action: .favorite, revision: library.revision, id: "213", selected: true))
      let previousRevision = library.revision
      library = try await db.filters.update(
        user.id, .init(action: .cutoff, revision: library.revision, id: "213", airflowCutoff: 1200))
      #expect(try await db.filters.fetch(user.id) == library)
      #expect(library.airflowCutoffs == ["213": 1200])
      #expect(library.suggestion(at: 1200) == nil)
      await #expect(throws: FilterError.self) {
        try await db.filters.update(
          user.id,
          .init(action: .cutoff, revision: previousRevision, id: "213", airflowCutoff: 1400))
      }
      try await db.filters.apply(user.id, project.id, .init(model: "213"))
      let loss = try #require(try await db.componentLosses.fetch(project.id).first)
      #expect(loss.value == 0.15)
      #expect(loss.name == "Aprilaire 213 filter")
      let cleared = try await db.filters.update(
        user.id, .init(action: .cutoff, revision: library.revision, id: "213"))
      #expect(try await db.filters.fetch(user.id).airflowCutoffs.isEmpty)
      #expect(cleared.suggestion(at: 1200)?.id == "213")
    }
  }
  @Test func accountLibraryPersistsAndRejectsStaleEdits() async throws {
    try await withTestUser { user in
      @Dependency(\.database) var db
      let other = try await db.users.create(
        .init(
          email: "other@example.test", password: "secret-password",
          confirmPassword: "secret-password"))
      let initial = try await db.filters.fetch(user.id)
      #expect(initial.filters == AirFilter.defaults)
      #expect(initial.favorites.isEmpty)
      #expect(initial.maximumPressureDrop == nil)
      let custom = AirFilter(
        id: "ignored", manufacturer: "Example", model: "Media",
        points: [
          .init(airflow: 1600, pressureDrop: 0.12), .init(airflow: 400, pressureDrop: 0.015),
        ])
      let saved = try await db.filters.update(
        user.id, .init(action: .save, revision: initial.revision, filter: custom, selected: true))
      let id = try #require(saved.favorites.first)
      let filter = try #require(saved.filters.first { $0.id == id })
      #expect(filter.id != custom.id)
      #expect(filter.points.first?.pressureDrop == 0.015)
      #expect(filter.source == nil)
      #expect(try await db.filters.fetch(user.id) == saved)
      #expect(try await db.filters.fetch(other.id) == initial)
      await #expect(throws: FilterError.self) {
        try await db.filters.update(
          user.id, .init(action: .delete, revision: initial.revision, id: id))
      }
      let deleted = try await db.filters.update(
        user.id, .init(action: .delete, revision: saved.revision, id: id))
      #expect(!deleted.filters.contains { $0.id == id })
      #expect(deleted.favorites.isEmpty)
      await #expect(throws: FilterError.self) {
        try await db.filters.update(
          other.id, .init(action: .favorite, revision: initial.revision, id: id, selected: true))
      }
      var library = deleted
      for filter in AirFilter.defaults {
        library = try await db.filters.update(
          user.id, .init(action: .delete, revision: library.revision, id: filter.id))
      }
      #expect(try await db.filters.fetch(user.id).filters.isEmpty)
      library = try await db.filters.update(
        user.id, .init(action: .restore, revision: library.revision, sources: ["213"]))
      #expect(library.filters.map(\.id) == ["213"])
      #expect(try await db.filters.fetch(user.id) == library)
    }
  }

  @Test func filterApplicationUsesCurrentChartAndPreservesExistingLosses() async throws {
    try await withTestUserAndProject { user, project in
      @Dependency(\.database) var db
      _ = try await db.equipment.create(
        .init(projectID: project.id, heatingCFM: 900, coolingCFM: 1200))
      try await db.componentLosses.applyTemplate(project.id, .furnace)
      #expect(try await db.componentLosses.fetch(project.id).count == 4)
      #expect(
        try await db.componentLosses.fetch(project.id).allSatisfy { !$0.name.contains("filter") })
      try await db.filters.apply(user.id, project.id, .init(model: "213", allowance: "0.03"))
      let loss = try #require(
        try await db.componentLosses.fetch(project.id).first { $0.name.contains("filter") })
      #expect(loss.value == 0.12)
      #expect(try await db.filters.allowance(project.id) == 0.03)
      let library = try await db.filters.fetch(user.id)
      var edited = try #require(library.filters.first { $0.id == "213" })
      edited.points[5].pressureDrop = 0.18
      let changed = try await db.filters.update(
        user.id, .init(action: .save, revision: library.revision, id: edited.id, filter: edited))
      #expect(try await db.componentLosses.get(loss.id) == loss)
      try await db.filters.apply(
        user.id, project.id, .init(model: "213", replacing: loss.id, allowance: "0.03"))
      #expect(try await db.componentLosses.get(loss.id)?.value == 0.15)
      try await db.filters.apply(
        user.id, project.id, .init(model: "213", replacing: loss.id, allowance: "0.20"))
      #expect(try await db.componentLosses.get(loss.id)?.value == 0)
      #expect(
        try await db.componentLosses.get(loss.id)?.name
          == "Aprilaire 213 filter (less 0.20 in equipment rating)")
      #expect(try await db.componentLosses.fetch(project.id).count == 5)
      #expect(try await db.filters.allowance(project.id) == 0.20)
      _ = try await db.filters.update(
        user.id, .init(action: .delete, revision: changed.revision, id: "213"))
      await #expect(throws: NotFoundError.self) {
        try await db.filters.apply(user.id, project.id, .init(model: "213"))
      }
      for allowance in ["-0.1", "nan", "inf", "2", "invalid"] {
        await #expect(throws: FilterError.self) {
          try await db.filters.apply(user.id, project.id, .init(model: "513", allowance: allowance))
        }
      }
      #expect(try await db.filters.allowance(project.id) == 0.20)
      let other = try await db.users.create(
        .init(
          email: "other@example.test", password: "secret-password",
          confirmPassword: "secret-password"))
      let foreign = try await db.projects.create(other.id, .mock)
      let foreignLoss = try await db.componentLosses.create(
        .init(projectID: foreign.id, name: "filter", value: 0.1))
      await #expect(throws: NotFoundError.self) {
        try await db.filters.apply(other.id, project.id, .init(model: "513"))
      }
      await #expect(throws: NotFoundError.self) {
        try await db.filters.apply(
          user.id, project.id, .init(model: "513", replacing: foreignLoss.id))
      }
      #expect(try await db.componentLosses.get(foreignLoss.id) == foreignLoss)
    }
  }
}
