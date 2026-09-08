import Foundation
import ManualDCore

struct TemplateCatalog: Decodable, Sendable {
  static let shared = Result {
    guard let url = Bundle.module.url(forResource: "template-catalog", withExtension: "json") else {
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
    let id: TemplateFitting.ID
    let group: TemplateFitting.Group
    let sourceCode: String?
    let name: String
    let artworkPath: String?
    let sourcePages: [Int]
    let notes: [String]
    let rule: Rule?

    var definition: TemplateFitting.Definition {
      .init(
        id: id, group: group, sourceCode: sourceCode, name: name, artworkPath: artworkPath,
        sourcePages: sourcePages, notes: notes,
        requirements: rule?.requirements
          ?? .unavailable(
            "Guided input controls are not yet supported. Use the project fitting picker.")
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

    var requirements: TemplateFitting.Requirements {
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

  // Template input transport is separate; all numeric results come from the current catalog.
  static let runtime = Result {
    guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
      throw CatalogError.missingResource
    }
    return try Catalog(data: Data(contentsOf: url))
  }

  func evaluate(
    _ request: TemplateFitting.EvaluationRequest,
    browse: @Sendable (Fitting.BrowseRequest) async throws -> [Fitting.Definition],
    evaluate: @Sendable (Fitting.EvaluationRequest) async throws -> Fitting.Evaluation
  ) async throws -> TemplateFitting.Evaluation {
    guard let entry = entries.first(where: { $0.id == request.fittingID }),
      entry.group.supports(request.type)
    else { return .unresolved("This fitting is unavailable for this path type.") }
    guard let rule = entry.rule else {
      return .unresolved(
        "This fitting's inputs are not yet supported in guided templates. Use the project fitting picker."
      )
    }
    guard rule.requirements.accepts(request.inputs),
      let group = Fitting.Group.ID(rawValue: entry.group.rawValue),
      let definition = try await browse(.init(pathType: request.type, groupID: group)).first(
        where: { $0.id.rawValue == entry.id.rawValue }),
      let inputs = Self.runtimeInputs(request.inputs, requirement: definition.inputRequirement)
    else { return .unresolved("Choose the source conditions for this fitting.") }
    switch try await evaluate(
      .init(pathType: request.type, fittingID: definition.id, inputs: inputs))
    {
    case .resolved(let calculation):
      return .resolved(
        .init(
          fittingID: entry.id, inputs: request.inputs,
          equivalentLengthFeet: calculation.equivalentLengthFeet,
          ruleRevision: calculation.ruleRevision, catalogCalculation: calculation))
    default:
      return .unresolved(
        "No supported calculation covers these inputs. Complete the source conditions and check the listed choices."
      )
    }
  }

  private static func runtimeInputs(
    _ inputs: TemplateFitting.Inputs, requirement: Fitting.InputRequirement
  ) -> Fitting.Inputs? {
    switch (inputs, requirement) {
    case (.fixed, .fixed): return .fixed
    case (.downstreamBranches(let count), .downstreamBranches):
      return .downstreamBranches(count: count)
    case (.dimensions(let h, let w), .heightWidth):
      return .heightWidth(heightInches: h, widthInches: w)
    case (.dimensions(let r, let w), .radiusWidth):
      return .radiusWidth(radiusInches: r, widthInches: w)
    case (.sourceTable(let choices), .plenumReturns):
      return .plenumReturns(
        count: choices.first.flatMap { $0 }.flatMap { Int($0.prefix(while: { $0.isNumber })) })
    case (.sourceTable(let choices), .roundElbow):
      let ratio = choices.first.flatMap { $0 }.flatMap { Double($0.split(separator: " ")[0]) }
        .flatMap(Fitting.RoundElbowRadiusRatio.init(rawValue:))
      let angle =
        choices.count == 1
        ? Fitting.ElbowAngle.degrees90
        : choices[1].flatMap(Int.init).flatMap(Fitting.ElbowAngle.init(rawValue:))
      return .roundElbow(radiusRatio: ratio, angle: angle)
    case (.sourceTable(let choices), .ovalElbow):
      return .ovalElbow(
        pieceCount: choices.first.flatMap { $0 }.flatMap(Int.init).flatMap(
          Fitting.OvalElbowPieceCount.init(rawValue:)))
    case (.sourceTable(let choices), .transition):
      guard choices.count == 2 else { return nil }
      return .transition(
        slope: choices[0].flatMap(Fitting.TransitionSlope.init(rawValue:)),
        areaRatio: choices[1].flatMap(Int.init).flatMap(Fitting.TransitionAreaRatio.init(rawValue:))
      )
    default: return nil
    }
  }

  enum CatalogError: Error { case missingResource, invalidResource }
}
