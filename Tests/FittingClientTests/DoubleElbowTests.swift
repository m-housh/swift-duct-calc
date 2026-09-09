import Foundation
import ManualDCore
import Testing

@testable import FittingClient

struct FittingDoubleElbowTests {
  let client: FittingClient

  init() async throws { client = try await loadBundledFittingClient() }

  @Test(arguments: ["8L-round", "8M-round", "8L-rectangular", "8M-rectangular"])
  func computesMatchingPairsAndRetainsBaseSnapshot(id: String) async throws {
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .elbows))
    let definition = try #require(definitions.first { $0.id.rawValue == id })
    guard case .doubleElbow(let bases) = definition.inputRequirement else {
      Issue.record("Missing base elbow choices")
      return
    }
    #expect(
      bases
        == (definition.shape == .round
          ? ["8A-smooth", "8A-4-or-5-piece", "8A-3-piece", "8A-mitered"]
          : ["8B", "8C", "8D", "8E"]))
    let multiplier = id.hasPrefix("8L") ? 1.7 : 2.0
    for baseID in bases {
      let base = try #require(definitions.first { $0.id == baseID })
      let choices: [Fitting.Inputs]
      switch base.inputRequirement {
      case .roundElbow(let ratios, _):
        choices = ratios.map { .roundElbow(radiusRatio: $0, angle: .degrees90) }
      case .rectangularElbow(let ratios, let categories, _):
        choices = ratios.flatMap { ratio in
          categories.map {
            .rectangularElbow(radiusRatio: ratio, bendCategory: $0, angle: .degrees90)
          }
        }
      case .squareElbow(let categories): choices = categories.map { .squareElbow(bendCategory: $0) }
      case .fixed: choices = [.fixed]
      default:
        Issue.record("Unexpected base rule")
        continue
      }
      for inputs in choices {
        for path in [Fitting.PathType.supply, .return] {
          let pairInputs = Fitting.Inputs.doubleElbow(baseFittingID: baseID, baseInputs: inputs)
          guard
            case .resolved(let value) = try await client.evaluate(
              .init(pathType: path, fittingID: definition.id, inputs: pairInputs)),
            case .resolved(let baseValue) = try await client.evaluate(
              .init(pathType: path, fittingID: baseID, inputs: inputs))
          else {
            Issue.record("Expected pair and base results")
            continue
          }
          #expect(value.equivalentLengthFeet == baseValue.equivalentLengthFeet * multiplier)
          #expect(value.components.count == 1)
          #expect(value.components[0].equivalentLengthFeet == value.equivalentLengthFeet)
          #expect(value.derivation == .scaled(base: baseValue, multiplier: multiplier))
          #expect(value.inputs == pairInputs)
          #expect(value.sourceCode?.rawValue == String(id.prefix(2)))
          #expect(
            try JSONDecoder().decode(
              Fitting.Calculation.self,
              from: JSONEncoder().encode(value)) == value)
        }
      }
    }
  }

  @Test func confirmedExampleAndIncompleteSelections() async throws {
    for (id, feet) in [("8L-round", 25.5), ("8M-round", 30.0)] {
      let request = Fitting.EvaluationRequest(
        pathType: .supply, fittingID: .init(rawValue: id),
        inputs: .doubleElbow(
          baseFittingID: "8A-smooth",
          baseInputs: .roundElbow(radiusRatio: .one, angle: .degrees90)))
      guard case .resolved(let value) = try await client.evaluate(request) else {
        Issue.record("Expected the confirmed example")
        continue
      }
      #expect(value.equivalentLengthFeet == feet)
    }
    let cases: [(Fitting.Inputs, [Fitting.Issue])] = [
      (
        .doubleElbow(baseFittingID: nil, baseInputs: nil),
        [.init(.missingInput, field: .baseFitting), .init(.missingInput, field: .baseInputs)]
      ),
      (
        .doubleElbow(baseFittingID: "8A-smooth", baseInputs: nil),
        [.init(.missingInput, field: .baseInputs)]
      ),
      (
        .doubleElbow(
          baseFittingID: "8A-smooth", baseInputs: .roundElbow(radiusRatio: nil, angle: .degrees90)),
        [.init(.missingInput, field: .radiusRatio)]
      ),
      (
        .doubleElbow(
          baseFittingID: "8A-smooth", baseInputs: .roundElbow(radiusRatio: .one, angle: nil)),
        [.init(.missingInput, field: .elbowAngle)]
      ),
    ]
    for (inputs, issues) in cases {
      #expect(
        try await client.evaluate(.init(pathType: .supply, fittingID: "8L-round", inputs: inputs))
          == .unresolved(issues))
    }
    guard case .available = try await client.artwork(.init(fittingID: "8L-round")) else {
      Issue.record("Pair artwork must be independent of base selection")
      return
    }
  }

  @Test func rejectsOtherAnglesShapesAndRecursiveArrangements() async throws {
    for id in [
      "8L-round", "8M-round", "8B", "8A-easy-bend", "8A-3-piece-45", "8G", "4A", "unknown",
    ] {
      #expect(
        try await client.evaluate(
          .init(
            pathType: .supply, fittingID: "8L-round",
            inputs: .doubleElbow(baseFittingID: .init(rawValue: id), baseInputs: .fixed)))
          == .unresolved([.init(.unsupportedCombination, field: .baseFitting)]))
    }
    for angle in Fitting.ElbowAngle.allCases where angle != .degrees90 {
      #expect(
        try await client.evaluate(
          .init(
            pathType: .supply, fittingID: "8L-round",
            inputs: .doubleElbow(
              baseFittingID: "8A-smooth",
              baseInputs: .roundElbow(radiusRatio: .one, angle: angle))))
          == .unresolved([.init(.unsupportedCombination, field: .elbowAngle)]))
    }
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: "8L-round",
          inputs: .doubleElbow(
            baseFittingID: "8A-smooth",
            baseInputs: .doubleElbow(baseFittingID: "8A-smooth", baseInputs: .fixed))))
        == .unresolved([.init(.incompatibleInputs, field: .baseInputs)]))
  }

  @Test func malformedCatalogCannotIntroduceARecursiveRule() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    var document = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf:
            root.appendingPathComponent("Sources/FittingClient/Resources/catalog.json")))
        as? [String: Any])
    var records = try #require(document["fittings"] as? [[String: Any]])
    let index = try #require(records.firstIndex { $0["id"] as? String == "8L-round" })
    var rule = try #require(records[index]["rule"] as? [String: Any])
    rule["baseFittingIDs"] = ["8L-round"]
    records[index]["rule"] = rule
    document["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: document)
    #expect(throws: CatalogValidator.ValidationError.self) {
      try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
    }
    let catalog = try Catalog(data: data)
    #expect(
      catalog.evaluate(
        .init(
          pathType: .supply, fittingID: "8L-round",
          inputs: .doubleElbow(baseFittingID: "8L-round", baseInputs: .fixed)))
        == .unresolved([.init(.unsupportedCombination, field: .baseFitting)]))
  }

  @Test func insideCornerValuesDefaultAndStrictCategoryIdentity() async throws {
    for (radius, feet) in [
      (Fitting.InsideCornerRadius.mitered, 235.0), (.oneQuarter, 90), (.greaterThanOneHalf, 45),
    ] {
      for path in [Fitting.PathType.supply, .return] {
        guard
          case .resolved(let value) = try await client.evaluate(
            .init(
              pathType: path,
              fittingID: "8O", inputs: .insideCornerOffset(radius: radius)))
        else {
          Issue.record("Expected printed inside-corner value")
          continue
        }
        #expect(value.equivalentLengthFeet == feet)
        #expect(value.inputs == .insideCornerOffset(radius: radius))
      }
    }
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .elbows))
    #expect(definitions.count == 25)
    let definition = try #require(definitions.first { $0.id == "8O" })
    #expect(definition.defaultInputs == .insideCornerOffset(radius: .mitered))
    #expect(
      definition.inputRequirement
        == .insideCornerOffset(radii: [.mitered, .oneQuarter, .greaterThanOneHalf]))
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: "8O",
          inputs: .insideCornerOffset(radius: nil)))
        == .unresolved([.init(.missingInput, field: .insideCornerRadius)]))
    #expect(Fitting.InsideCornerRadius.greaterThanOneHalf.label == "R > 0.50")
    for raw in ["0.5", #""oneHalf""#, #""oneHalfOrGreater""#] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.InsideCornerRadius.self, from: Data(raw.utf8))
      }
    }
  }
}
