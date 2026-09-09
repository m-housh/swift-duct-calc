import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingFlexJunctionBoxTests {
  let client: FittingClient
  init() async throws { client = try await loadBundledFittingClient() }

  @Test func allBoxAndBendCells() async throws {
    let boxes: [Double] = [20, 30, 40, 60, 75, 95]
    let bends: [[Double]] = [
      [5, 5, 5, 5], [5, 5, 5, 5], [10, 5, 5, 5], [15, 10, 5, 5], [15, 10, 10, 8], [20, 15, 10, 8],
    ]
    for path in [Fitting.PathType.supply, .return] {
      for (i, velocity) in Fitting.FlexVelocity.allCases.enumerated() {
        let boxInputs = Fitting.Inputs.flexJunctionBox(
          boxVelocity: velocity, openings: .sidewall,
          suppliedBend: false, bendVelocity: nil, bendRadiusRatio: nil)
        let box = try await value(boxInputs, path: path)
        #expect(box.equivalentLengthFeet == boxes[i])
        #expect(box.components.count == 1)
        for (j, ratio) in Fitting.FlexBendRadiusRatio.allCases.enumerated() {
          // Keep box velocity fixed to prove the bend has an independent input.
          let inputs = Fitting.Inputs.flexJunctionBox(
            boxVelocity: .fpm700, openings: .sidewall,
            suppliedBend: true, bendVelocity: velocity, bendRadiusRatio: ratio)
          let pair = try await value(inputs, path: path)
          #expect(pair.equivalentLengthFeet == 60 + bends[i][j])
          #expect(pair.components.map(\.equivalentLengthFeet) == [60, bends[i][j]])
          #expect(pair.inputs == inputs)
          #expect(pair.sourceCode == nil)
          #expect(
            try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(pair))
              == pair)
        }
      }
    }
  }

  @Test func defaultsIncompleteAndUnsupportedOpenings() async throws {
    let definition = try #require(
      try await client.fittings(.init(pathType: .supply, groupID: .flexJunctions)).first)
    #expect(definition.id == "11-junction-box" && definition.sourceCode == nil)
    #expect(
      definition.defaultInputs
        == .flexJunctionBox(
          boxVelocity: .fpm700, openings: .sidewall,
          suppliedBend: false, bendVelocity: .fpm700, bendRadiusRatio: .one))
    #expect(try await value(definition.defaultInputs).equivalentLengthFeet == 60)
    let cases: [(Fitting.Inputs, [Fitting.Issue])] = [
      (
        .flexJunctionBox(
          boxVelocity: nil, openings: nil, suppliedBend: true, bendVelocity: nil,
          bendRadiusRatio: nil),
        [
          .init(.missingInput, field: .flexVelocity), .init(.missingInput, field: .flexOpenings),
          .init(.missingInput, field: .bendVelocity), .init(.missingInput, field: .bendRadiusRatio),
        ]
      ),
      (
        .flexJunctionBox(
          boxVelocity: .fpm700, openings: .topOrBottom, suppliedBend: false,
          bendVelocity: .fpm700, bendRadiusRatio: .one),
        [.init(.unsupportedCombination, field: .flexOpenings)]
      ),
      (.fixed, [.init(.incompatibleInputs)]),
    ]
    for (inputs, issues) in cases {
      #expect(
        try await client.evaluate(
          .init(pathType: .supply, fittingID: definition.id, inputs: inputs)) == .unresolved(issues)
      )
    }
    #expect(try await client.resolveReference(.init(code: "11A", pathType: .supply)) == .unknown)
    #expect(
      try await client.resolveReference(.init(code: "11-junction-box", pathType: .supply))
        == .unknown)
    for view in [Fitting.View.individual, .suppliedBend, .bendDetail] {
      guard
        case .available(let artwork) = try await client.artwork(
          .init(fittingID: definition.id, view: view))
      else {
        Issue.record("Missing independent schematic")
        continue
      }
      #expect(artwork.publicPath.hasPrefix("/images/fittings/group-11/"))
    }
  }

  @Test func disabledBendPreservesDraftSelectionsWithoutAddingLength() async throws {
    let inputs = Fitting.Inputs.flexJunctionBox(
      boxVelocity: .fpm700, openings: .sidewall,
      suppliedBend: false, bendVelocity: .fpm900, bendRadiusRatio: .fourToFive)
    let box = try await value(inputs)
    #expect(box.equivalentLengthFeet == 60 && box.inputs == inputs)
    #expect(
      try await value(
        .flexJunctionBox(
          boxVelocity: .fpm700, openings: .sidewall,
          suppliedBend: true, bendVelocity: .fpm700, bendRadiusRatio: .one)
      ).equivalentLengthFeet == 75)
    for raw in [399, 650, 901] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.FlexVelocity.self, from: Data(String(raw).utf8))
      }
    }
  }

  private func value(_ inputs: Fitting.Inputs, path: Fitting.PathType = .supply) async throws
    -> Fitting.Calculation
  {
    guard
      case .resolved(let value) = try await client.evaluate(
        .init(pathType: path, fittingID: "11-junction-box", inputs: inputs))
    else { throw LookupError.unresolved }
    return value
  }
  enum LookupError: Error { case unresolved }
}
