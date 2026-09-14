import Foundation

/// An account's filter chart. Project component losses retain a copy of the chosen value.
public struct AirFilter: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var manufacturer: String
  public var model: String
  public var description: String
  public var points: [Point]
  public var source: String?

  public struct Point: Codable, Equatable, Sendable {
    public var airflow: Int
    public var pressureDrop: Double
    public init(airflow: Int, pressureDrop: Double) {
      self.airflow = airflow
      self.pressureDrop = pressureDrop
    }
  }

  public init(
    id: String, manufacturer: String, model: String, description: String = "",
    points: [Point], source: String? = nil
  ) {
    self.id = id
    self.manufacturer = manufacturer
    self.model = model
    self.description = description
    self.points = points
    self.source = source
  }

  public var name: String { "\(manufacturer) \(model)".trimmingCharacters(in: .whitespaces) }
  public var maxCFM: Int { points.last?.airflow ?? 0 }
  public var isEdited: Bool {
    guard let original = Self.defaults.first(where: { $0.source == source }), source != nil else {
      return false
    }
    return manufacturer != original.manufacturer || model != original.model
      || description != original.description || points != original.points
  }

  public func validated() throws -> Self {
    var result = self
    result.manufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
    result.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
    result.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !result.model.isEmpty, result.model.count <= 100, result.manufacturer.count <= 100,
      result.description.count <= 300
    else {
      throw FilterError(
        "Enter a model or name, up to 100 characters. Keep the description under 300 characters.")
    }
    if result.manufacturer.isEmpty { result.manufacturer = "Other" }
    guard (2...100).contains(points.count),
      points.allSatisfy({
        (1...100_000).contains($0.airflow) && $0.pressureDrop.isFinite && $0.pressureDrop > 0
          && $0.pressureDrop <= 1
      }), Set(points.map(\.airflow)).count == points.count
    else {
      throw FilterError(
        "Enter 2 to 100 distinct airflow points, with positive whole CFM up to 100,000 and pressure drops above 0 and at most 1.00 in. w.c."
      )
    }
    result.points.sort { $0.airflow < $1.airflow }
    return result
  }

  /// Interpolates chart points, extending the end segments outside the chart; rounds up to 0.01.
  public func pressureDrop(at airflow: Int) -> Double {
    guard airflow > 0, points.count >= 2 else { return 0 }
    let chart = points
    let upper = chart.firstIndex { $0.airflow >= airflow } ?? chart.count - 1
    let low = chart[max(1, upper) - 1]
    let high = chart[max(1, upper)]
    let drop =
      low.pressureDrop + (high.pressureDrop - low.pressureDrop)
      * Double(airflow - low.airflow) / Double(high.airflow - low.airflow)
    return max(0.01, (drop * 100 - 1e-9).rounded(.up) / 100)
  }

  public func additionalPressureDrop(at airflow: Int, allowance: Double?) -> Double {
    max(0, ((pressureDrop(at: airflow) - (allowance ?? 0)) * 100).rounded() / 100)
  }

  public static let defaults = AprilaireFilter.all.map { filter in
    Self(
      id: filter.model, manufacturer: "Aprilaire", model: filter.model,
      description: filter.rating.title,
      points: filter.pressureDrops.enumerated().map {
        Point(airflow: filter.firstCFM + $0.offset * AprilaireFilter.step, pressureDrop: $0.element)
      }, source: filter.model)
  }

  public struct Selection: Equatable, Sendable {
    public let model: String
    public let replacing: ComponentPressureLoss.ID?
    public let allowance: String
    public init(model: String, replacing: ComponentPressureLoss.ID? = nil, allowance: String = "") {
      self.model = model
      self.replacing = replacing
      self.allowance = allowance
    }
    public func validatedAllowance() throws -> Double? {
      if allowance.isEmpty { return nil }
      guard let value = Double(allowance), value.isFinite, value > 0, value <= 1 else {
        throw FilterError(
          "Enter an equipment filter allowance above 0 and at most 1.00 in. w.c., or leave it blank."
        )
      }
      return value
    }
  }
}

public struct FilterError: LocalizedError, Equatable, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}

/// Saved as one small account document; revisions prevent a stale editor from overwriting changes.
public struct FilterLibrary: Codable, Equatable, Sendable {
  public var revision: UUID
  public var filters: [AirFilter]
  public var favorites: [String]
  public var maximumPressureDrop: Double?
  public var airflowCutoffs: [String: Int]
  public init(
    revision: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
    filters: [AirFilter] = AirFilter.defaults, favorites: [String] = [],
    maximumPressureDrop: Double? = nil, airflowCutoffs: [String: Int] = [:]
  ) {
    self.revision = revision
    self.filters = filters
    self.favorites = favorites
    self.maximumPressureDrop = maximumPressureDrop
    self.airflowCutoffs = airflowCutoffs
  }
  private enum CodingKeys: String, CodingKey {
    case revision, filters, favorites, maximumPressureDrop, airflowCutoffs
  }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    revision = try container.decode(UUID.self, forKey: .revision)
    filters = try container.decode([AirFilter].self, forKey: .filters)
    favorites = try container.decode([String].self, forKey: .favorites)
    maximumPressureDrop = try container.decodeIfPresent(Double.self, forKey: .maximumPressureDrop)
    // Libraries saved before airflow preferences have no additional cutoffs.
    airflowCutoffs =
      try container.decodeIfPresent([String: Int].self, forKey: .airflowCutoffs) ?? [:]
  }
  public var preferredFilters: [AirFilter] {
    favorites.compactMap { id in filters.first { $0.id == id } }
  }
  public func suggestion(at airflow: Int) -> AirFilter? {
    guard airflow > 0 else { return nil }
    return preferredFilters.first { suggestionSkipReason(for: $0, at: airflow) == nil }
  }
  public func suggestionSkipReason(for filter: AirFilter, at airflow: Int) -> String? {
    if let cutoff = airflowCutoffs[filter.id], airflow >= cutoff {
      return "At or above your \(cutoff) CFM cutoff"
    }
    if airflow > filter.maxCFM { return "Over max CFM" }
    if let maximumPressureDrop, filter.pressureDrop(at: airflow) > maximumPressureDrop + 1e-9 {
      return "Over pressure limit"
    }
    return nil
  }
  private mutating func removeFavorite(_ id: String) {
    favorites.removeAll { $0 == id }
    airflowCutoffs.removeValue(forKey: id)
  }

  public struct Change: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
      case save, delete, favorite, move, maximum, cutoff, restore
    }
    public var action: Action
    public var revision: UUID
    public var id: String?
    public var filter: AirFilter?
    public var selected: Bool?
    public var direction: Int?
    public var maximumPressureDrop: Double?
    public var airflowCutoff: Int?
    public var sources: [String]?
    public init(
      action: Action, revision: UUID, id: String? = nil, filter: AirFilter? = nil,
      selected: Bool? = nil, direction: Int? = nil, maximumPressureDrop: Double? = nil,
      sources: [String]? = nil, airflowCutoff: Int? = nil
    ) {
      self.action = action
      self.revision = revision
      self.id = id
      self.filter = filter
      self.selected = selected
      self.direction = direction
      self.maximumPressureDrop = maximumPressureDrop
      self.sources = sources
      self.airflowCutoff = airflowCutoff
    }
  }

  public mutating func apply(_ change: Change, newID: String, revision: UUID) throws {
    guard change.revision == self.revision else {
      throw FilterError("Your filter library changed in another tab. Reload before saving again.")
    }
    let index = filters.firstIndex { $0.id == change.id }
    switch change.action {
    case .save:
      guard let input = change.filter else { throw FilterError("Enter a filter chart.") }
      var filter = try input.validated()
      if let id = change.id {
        guard let index else { throw FilterError("This filter is no longer in your library.") }
        filter.id = id
        filter.source = filters[index].source
      } else {
        filter.id = newID
        filter.source = nil
      }
      guard
        !filters.contains(where: {
          $0.id != filter.id && $0.name.lowercased() == filter.name.lowercased()
        })
      else {
        throw FilterError("A filter with that manufacturer and model is already in your library.")
      }
      if let index {
        filters[index] = filter
      } else {
        guard filters.count < 500 else {
          throw FilterError("Your library can contain up to 500 filters.")
        }
        filters.append(filter)
      }
      if change.selected == true && !favorites.contains(filter.id) { favorites.append(filter.id) }
      if change.selected == false { removeFavorite(filter.id) }
    case .delete:
      guard let index else { throw FilterError("This filter is no longer in your library.") }
      let id = filters.remove(at: index).id
      removeFavorite(id)
    case .favorite:
      guard let index, let selected = change.selected else {
        throw FilterError("Choose a filter from your library.")
      }
      let id = filters[index].id
      if selected {
        if !favorites.contains(id) { favorites.append(id) }
      } else {
        removeFavorite(id)
      }
    case .move:
      guard let id = change.id, let i = favorites.firstIndex(of: id),
        let direction = change.direction,
        [-1, 1].contains(direction), favorites.indices.contains(i + direction)
      else {
        throw FilterError("Choose a favorite and a valid position.")
      }
      favorites.swapAt(i, i + direction)
    case .maximum:
      if let value = change.maximumPressureDrop {
        guard value.isFinite, value > 0, value <= 1 else {
          throw FilterError("Enter a maximum above 0 and at most 1.00 in. w.c., or leave it blank.")
        }
      }
      maximumPressureDrop = change.maximumPressureDrop
    case .cutoff:
      guard let id = change.id, index != nil, favorites.contains(id) else {
        throw FilterError("Choose a favorite from your library.")
      }
      if let cutoff = change.airflowCutoff, !(1...100_000).contains(cutoff) {
        throw FilterError("Enter positive whole CFM up to 100,000, or leave the cutoff blank.")
      }
      airflowCutoffs[id] = change.airflowCutoff
    case .restore:
      let sources = Set(change.sources ?? [])
      guard !sources.isEmpty, sources.isSubset(of: Set(AirFilter.defaults.compactMap(\.source)))
      else {
        throw FilterError("Choose the Aprilaire filters to restore.")
      }
      for original in AirFilter.defaults where sources.contains(original.source!) {
        guard
          !filters.contains(where: {
            $0.source != original.source && $0.name.lowercased() == original.name.lowercased()
          })
        else {
          throw FilterError(
            "Rename or delete the existing \(original.name) entry before restoring the Aprilaire chart."
          )
        }
        if let i = filters.firstIndex(where: { $0.source == original.source }) {
          var restored = original
          restored.id = filters[i].id
          filters[i] = restored
        } else {
          filters.append(original)
        }
      }
    }
    guard filters.count <= 500 else {
      throw FilterError("Your library can contain up to 500 filters.")
    }
    self.revision = revision
  }
}
