import DatabaseClient
import Dependencies
import Elementary
import Foundation
import ManualDCore

extension SiteRoute.View.UserRoute.FilterRoute {
  func renderView(on request: ViewController.Request) async throws -> AnySendableHTML {
    @Dependency(\.database.filters) var filters
    let user = try request.currentUser()
    do {
      switch self {
      case .index(let query):
        guard (1...100_000).contains(query.airflow) else {
          throw FilterError("Enter positive whole CFM up to 100,000.")
        }
        let library = try await filters.fetch(user.id)
        return await request.view { FilterAccountView(library: library, query: query) }
      case .editor(let id, let duplicate):
        let library = try await filters.fetch(user.id)
        let filter = library.filters.first { $0.id == id }
        if id != nil && filter == nil { throw NotFoundError() }
        return FilterEditorView(library: library, filter: filter, duplicate: duplicate == "true")
      case .update(let change):
        let library = try await filters.update(user.id, change)
        return div(.data("filter-revision", value: library.revision.uuidString)) {
          "Filter settings saved."
        }
      case .preview(let input):
        guard (1...100_000).contains(input.airflow) else {
          throw FilterError("Enter positive whole CFM up to 100,000.")
        }
        return FilterChartResult(filter: try input.filter.validated(), airflow: input.airflow)
      }
    } catch let error as FilterError {
      throw PresentationError(title: "Could not save filter settings", message: error.message)
    }
  }
}

func filterJSON<T: Encodable>(_ value: T) -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  return String(decoding: (try? encoder.encode(value)) ?? Data(), as: UTF8.self)
}
func filterNumber(_ value: Double) -> String { String(format: "%.2f", value) }
