import Foundation
import ManualDCore

/// Normalizes reference navigation once for both HTML and downloadable exports.
public struct FittingReferencePage: Sendable {
  public let catalog: FittingReference
  public let system: String
  public let group: String
  public let search: String
  public let type: String
  public let format: String
  public let scope: String
  public let showData: Bool
  public let isLoggedIn: Bool
  public let groups: [FittingReference.Group]
  public let rows: [FittingReference.Entry]
  public let selected: FittingReference.Entry?
  public let exportText: String

  public init(catalog: FittingReference, query: SiteRoute.View.FittingsQuery, isLoggedIn: Bool)
    throws
  {
    self.catalog = catalog
    self.isLoggedIn = isLoggedIn
    system = ["supply", "return"].contains(query.system) ? query.system! : "all"
    groups = catalog.groups(for: system)
    let initial = catalog.entries.first { $0.id == query.fitting }
    var group: String
    if query.group == "all" {
      group = "all"
    } else if let requested = query.group,
      catalog.groups.contains(where: { String($0.id) == requested })
    {
      group = requested
    } else {
      group = String(initial?.record.group ?? 1)
    }
    if group != "all", !groups.contains(where: { String($0.id) == group }) {
      group = String(groups.first?.id ?? 1)
    }
    self.group = group
    search = query.q ?? ""
    type = ["fixed", "conditional"].contains(query.type) ? query.type! : "all"
    format = ["json", "csv", "path"].contains(query.data) ? query.data! : "json"
    scope = query.scope == "filtered" && format != "path" ? "filtered" : "record"
    rows = catalog.filter(group: group, query: search, type: type, system: system)
    selected = rows.first { $0.id == initial?.id } ?? rows.first
    showData = isLoggedIn && ["json", "csv", "path"].contains(query.data)
    exportText =
      showData && selected != nil
      ? try FittingReference.export(
        scope == "filtered" ? rows : selected.map { [$0] } ?? [], format: format) : ""
  }

  public var hasData: Bool { showData && selected != nil }
  public var allGroupsLabel: String { system == "all" ? "All groups" : "All \(system) groups" }
  public var filename: String {
    "fitting-\(format == "path" ? "path-example" : "reference").\(format == "csv" ? "csv" : "json")"
  }

  public func path(_ changes: [String: String] = [:]) -> String {
    var values = [
      "system": system == "all" ? "" : system, "group": group, "fitting": selected?.id ?? "",
      "q": search, "type": type == "all" ? "" : type, "data": showData ? format : "",
      "scope": showData && scope == "filtered" ? scope : "",
    ]
    values.merge(changes) { _, new in new }
    func value(_ key: String) -> String? { values[key].flatMap { $0.isEmpty ? nil : $0 } }
    return SiteRoute.View.router.path(
      for: .fittingReference(
        .init(
          system: value("system"), group: value("group"), fitting: value("fitting"), q: value("q"),
          type: value("type"), data: value("data"), scope: value("scope"),
          download: value("download")
        ))
    )
    .replacingOccurrences(of: "+", with: "%2B")
  }

  public var loginPath: String {
    var components = URLComponents()
    components.path = "/login"
    components.queryItems = [URLQueryItem(name: "next", value: path(["data": format]))]
    return components.string!
  }
}
