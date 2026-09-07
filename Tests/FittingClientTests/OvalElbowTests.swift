import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingOvalElbowTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  // Independently read from the 8A table on printed page 176 (viewer page 32).
  @Test(arguments: [
    ("8A-mitered", Fitting.Inputs.fixed, 75.0),
    ("8A-easy-bend", .ovalElbow(pieceCount: .three), 30),
    ("8A-easy-bend", .ovalElbow(pieceCount: .four), 25),
    ("8A-hard-bend", .ovalElbow(pieceCount: .three), 35),
    ("8A-hard-bend", .ovalElbow(pieceCount: .four), 30),
    ("8A-3-piece-45", .fixed, 10),
    ("8A-2-piece-45", .fixed, 15),
  ])
  func publishedConstructionValues(id: String, inputs: Fitting.Inputs, feet: Double) async throws {
    for path in [Fitting.PathType.supply, .return] {
      let result = try await client.evaluate(
        .init(pathType: path, fittingID: .init(rawValue: id), inputs: inputs))
      guard case .resolved(let value) = result else {
        Issue.record("Expected a source length for \(id)")
        continue
      }
      #expect(value.equivalentLengthFeet == feet)
      #expect(value.inputs == inputs)
      #expect(value.sourceCode == "8A")
      #expect(value.components.count == 1)
      if case .ovalElbow(let count) = inputs {
        #expect(value.components[0].ruleKey == "\(id):pieces:\(count!.rawValue)")
      }
      #expect(
        try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(value)) == value)
    }
  }

  @Test func allConstructionsResolveWithoutInferringOneFromTheSourceCode() async throws {
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .elbows))
      .filter { $0.familyID == "8A" }
    let ids: [Fitting.ID] = [
      "8A-smooth", "8A-4-or-5-piece", "8A-3-piece", "8A-mitered", "8A-easy-bend",
      "8A-hard-bend", "8A-3-piece-45", "8A-2-piece-45",
    ]
    #expect(definitions.map(\.id) == ids)
    #expect(
      try await client.resolveReference(.init(code: " 8a ", pathType: .return))
        == .recognized(.init(code: "8A", groupID: .elbows, fittingIDs: ids)))
    for definition in definitions where definition.shape == .oval {
      #expect(definition.inputRequirement == .ovalElbow(pieceCounts: [.three, .four]))
      #expect(definition.defaultInputs == .ovalElbow(pieceCount: nil))
      #expect(
        try await client.evaluate(
          .init(pathType: .supply, fittingID: definition.id, inputs: definition.defaultInputs))
          == .unresolved([.init(.missingInput, field: .pieceCount)]))
      guard case .available(let artwork) = try await client.artwork(.init(fittingID: definition.id))
      else {
        Issue.record("Drawing must be available before choosing a piece count")
        continue
      }
      #expect(artwork.publicPath == "/images/fittings/group-8/\(definition.id.rawValue).svg")
    }
    #expect(Fitting.OvalElbowPieceCount.allCases.map(\.label) == ["3-piece", "4-piece"])
  }

  @Test func incompatibleAndUnlistedConstructionInputsAreRejected() async throws {
    for id in ["8A-mitered", "8A-easy-bend", "8A-hard-bend", "8A-3-piece-45", "8A-2-piece-45"] {
      #expect(
        try await client.evaluate(
          .init(
            pathType: .supply, fittingID: .init(rawValue: id),
            inputs: .roundElbow(radiusRatio: .one, angle: .degrees45)))
          == .unresolved([.init(.incompatibleInputs)]))
    }
    for count in [0, 2, 5] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.OvalElbowPieceCount.self, from: Data(String(count).utf8))
      }
    }
  }
}
