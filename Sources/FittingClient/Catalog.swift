import Foundation
import ManualDCore

struct Catalog: Decodable, Sendable {
  static let shared = Result {
    guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
      throw CatalogError.missingResource
    }
    let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    guard catalog.revision == "2026-09-08.1",
      Set(catalog.entries.map(\.id)).count == catalog.entries.count
    else { throw CatalogError.invalidResource }
    for entry in catalog.entries { try entry.rule?.validate() }
    return catalog
  }

  let revision: String
  let entries: [Entry]

  struct Entry: Decodable, Sendable {
    let id: Fitting.ID
    let group: Fitting.Group
    let sourceCode: String?
    let name: String
    let artworkPath: String?
    let sourcePages: [Int]
    let notes: [String]
    let rule: Rule?

    var definition: Fitting.Definition {
      .init(
        id: id, group: group, sourceCode: sourceCode, name: name, artworkPath: artworkPath,
        sourcePages: sourcePages, notes: notes,
        requirements: rule?.requirements
          ?? .unavailable("Calculation awaiting source verification.")
      )
    }
  }

  struct Rule: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable {
      case fixed, dimensions, downstreamBranches, sourceTable
    }
    let kind: Kind
    let feet: Double?
    let labels: [String]?
    let rows: [Row]?

    func validate() throws {
      func require(_ condition: Bool) throws {
        guard condition else { throw CatalogError.invalidResource }
      }
      if kind == .fixed {
        try require(feet.map { $0.isFinite && $0 > 0 } ?? false)
        return
      }
      guard let rows, !rows.isEmpty else { throw CatalogError.invalidResource }
      try require(rows.allSatisfy { $0.feet.isFinite && $0.feet > 0 })
      switch kind {
      case .dimensions:
        try require(labels?.count == 2)
        try require(rows.allSatisfy { $0.ratio.map { $0.isFinite && $0 > 0 } ?? false })
      case .downstreamBranches:
        try require(
          rows.allSatisfy { row in
            guard let minimum = row.minimum, minimum >= 0 else { return false }
            return row.maximum.map { $0 >= minimum } ?? true
          })
      case .sourceTable:
        guard let labels, !labels.isEmpty else { throw CatalogError.invalidResource }
        try require(rows.allSatisfy { $0.keys?.count == labels.count })
      case .fixed: break
      }
    }

    var requirements: Fitting.Requirements {
      switch kind {
      case .fixed: return .fixed
      case .dimensions: return .dimensions(numerator: labels![0], denominator: labels![1])
      case .downstreamBranches: return .downstreamBranches
      case .sourceTable:
        return .sourceTable(
          axes: (labels ?? []).enumerated().map { index, label in
            var options = [String]()
            for row in rows ?? [] {
              if let key = row.keys?[index], !options.contains(key) { options.append(key) }
            }
            return .init(label: label, options: options)
          })
      }
    }
  }

  struct Row: Decodable, Sendable {
    let feet: Double
    let ratio: Double?
    let minimum: Int?
    let maximum: Int?
    let keys: [String]?
  }

  func evaluate(_ request: Fitting.EvaluationRequest) -> Fitting.Evaluation {
    guard let entry = entries.first(where: { $0.id == request.fittingID }),
      entry.group.supports(request.type)
    else { return .unresolved("This fitting is unavailable for this path type.") }
    guard let rule = entry.rule else {
      return .unresolved("This fitting's calculation is awaiting source verification.")
    }
    guard rule.requirements.accepts(request.inputs) else {
      return .unresolved("Choose the source conditions for this fitting.")
    }
    let value: Double?
    switch request.inputs {
    case .fixed:
      value = rule.feet
    case .dimensions(let numerator, let denominator):
      guard let numerator, let denominator, numerator.isFinite, denominator.isFinite,
        numerator > 0, denominator > 0
      else { return .unresolved("Enter both positive dimensions marked on the drawing.") }
      let ratio = numerator / denominator
      value =
        rule.rows?.first { row in
          row.ratio.map { abs($0 - ratio) < 1e-9 } ?? false
        }?.feet
    case .downstreamBranches(let count):
      guard let count, count >= 0 else {
        return .unresolved("Enter the downstream branch count, including zero when there are none.")
      }
      value =
        rule.rows?.first {
          count >= ($0.minimum ?? 0) && ($0.maximum.map { count <= $0 } ?? true)
        }?.feet
    case .sourceTable(let choices):
      guard choices.allSatisfy({ $0 != nil }) else {
        return .unresolved("Choose each required source condition.")
      }
      value = rule.rows?.first { $0.keys == choices.compactMap { $0 } }?.feet
    case .flexJunctionBox:
      value = nil
    }
    guard let value, value.isFinite, value > 0 else {
      return .unresolved(
        "No exact source entry covers these inputs. Interpolation is not available.")
    }
    return .resolved(
      .init(
        fittingID: entry.id, inputs: request.inputs, equivalentLengthFeet: value,
        ruleRevision: revision
      ))
  }

  enum CatalogError: Error { case missingResource, invalidResource }
}
