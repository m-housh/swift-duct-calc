import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingOffsetTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  // All cells independently transcribed from printed page 177, viewer pages 34–35.
  @Test(arguments: [
    ("8D", Fitting.Inputs.squareElbow(bendCategory: .hardBend), 80.0),
    ("8D", .squareElbow(bendCategory: .square), 80),
    ("8D", .squareElbow(bendCategory: .easyBend), 65),
    ("8E", .squareElbow(bendCategory: .hardBend), 10),
    ("8E", .squareElbow(bendCategory: .square), 10),
    ("8E", .squareElbow(bendCategory: .easyBend), 10),
    ("8F", .steppedOffset(lengthHeightRatio: .one), 160),
    ("8F", .steppedOffset(lengthHeightRatio: .two), 260),
    ("8F", .steppedOffset(lengthHeightRatio: .four), 190),
    ("8G", .fixed, 200),
    ("8H", .fourTurnOffset(heightLengthRatio: .oneHalf, turningVanes: false), 55),
    ("8H", .fourTurnOffset(heightLengthRatio: .one, turningVanes: false), 330),
    ("8H", .fourTurnOffset(heightLengthRatio: .oneAndHalf, turningVanes: false), 430),
    ("8H", .fourTurnOffset(heightLengthRatio: .two, turningVanes: false), 470),
    ("8H", .fourTurnOffset(heightLengthRatio: .one, turningVanes: true), 55),
    ("8H", .fourTurnOffset(heightLengthRatio: .oneAndHalf, turningVanes: true), 55),
    ("8H", .fourTurnOffset(heightLengthRatio: .two, turningVanes: true), 55),
    ("8I", .fixed, 20),
    ("8J", .fixed, 20),
    ("8K", .radiusOffset(radiusHeightRatio: .mitered), 250),
    ("8K", .radiusOffset(radiusHeightRatio: .oneQuarter), 100),
    ("8K", .radiusOffset(radiusHeightRatio: .oneHalf), 20),
    ("8K", .radiusOffset(radiusHeightRatio: .one), 20),
    ("8N", .fixed, 10),
    ("8P", .riserElbow(size: .threeAndQuarterByTen, corner: .miter), 75),
    ("8P", .riserElbow(size: .threeAndQuarterByTen, corner: .radius), 60),
    ("8P", .riserElbow(size: .threeAndQuarterByTwelve, corner: .miter), 90),
    ("8P", .riserElbow(size: .threeAndQuarterByTwelve, corner: .radius), 75),
    ("8P", .riserElbow(size: .threeAndQuarterByFourteen, corner: .miter), 90),
    ("8P", .riserElbow(size: .threeAndQuarterByFourteen, corner: .radius), 75),
  ])
  func publishedValues(id: String, inputs: Fitting.Inputs, feet: Double) async throws {
    for path in [Fitting.PathType.supply, .return] {
      let result = try await client.evaluate(
        .init(pathType: path, fittingID: .init(rawValue: id), inputs: inputs))
      guard case .resolved(let value) = result else {
        Issue.record("Expected a source length for \(id)")
        continue
      }
      #expect(value.equivalentLengthFeet == feet)
      #expect(value.sourceCode?.rawValue == id)
      #expect(value.inputs == inputs)
      #expect(value.components.count == 1)
      #expect(value.components[0].equivalentLengthFeet == feet)
      if case .fourTurnOffset(_, let vanes) = inputs {
        #expect(value.components[0].ruleKey.hasSuffix(vanes ? ":with-vanes" : ":without-vanes"))
      }
      #expect(value.conditions.referenceVelocityFPM == 900)
      #expect(value.conditions.frictionRateIWCPer100Feet == 0.08)
      #expect(
        try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(value))
          == value)
    }
  }

  @Test func missingInputsRemainMissingAndArtworkRemainsAvailable() async throws {
    let cases: [(String, Fitting.InputRequirement, Fitting.Inputs, [Fitting.Issue])] = [
      (
        "8D", .squareElbow(bendCategories: [.hardBend, .square, .easyBend]),
        .squareElbow(bendCategory: nil), [.init(.missingInput, field: .bendCategory)]
      ),
      (
        "8E", .squareElbow(bendCategories: [.hardBend, .square, .easyBend]),
        .squareElbow(bendCategory: nil), [.init(.missingInput, field: .bendCategory)]
      ),
      (
        "8F", .steppedOffset(lengthHeightRatios: [.one, .two, .four]),
        .steppedOffset(lengthHeightRatio: nil), [.init(.missingInput, field: .offsetRatio)]
      ),
      (
        "8H",
        .fourTurnOffset(
          heightLengthRatios: [.oneHalf, .one, .oneAndHalf, .two],
          vanedRatios: [.one, .oneAndHalf, .two]),
        .fourTurnOffset(heightLengthRatio: nil, turningVanes: false),
        [.init(.missingInput, field: .offsetRatio)]
      ),
      (
        "8K", .radiusOffset(radiusHeightRatios: [.mitered, .oneQuarter, .oneHalf, .one]),
        .radiusOffset(radiusHeightRatio: nil), [.init(.missingInput, field: .offsetRatio)]
      ),
      (
        "8P",
        .riserElbow(
          sizes: [.threeAndQuarterByTen, .threeAndQuarterByTwelve, .threeAndQuarterByFourteen],
          corners: [.miter, .radius]),
        .riserElbow(size: nil, corner: nil),
        [.init(.missingInput, field: .riserSize), .init(.missingInput, field: .riserCorner)]
      ),
    ]
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .elbows))
    for (id, requirement, inputs, issues) in cases {
      let definition = try #require(definitions.first { $0.id.rawValue == id })
      #expect(definition.inputRequirement == requirement)
      #expect(definition.defaultInputs == inputs)
      #expect(
        try await client.evaluate(
          .init(pathType: .supply, fittingID: definition.id, inputs: inputs))
          == .unresolved(issues))
      guard case .available(let artwork) = try await client.artwork(.init(fittingID: definition.id))
      else {
        Issue.record("Drawing must be available before completing \(id)")
        continue
      }
      #expect(artwork.publicPath == "/images/fittings/group-8/\(id).svg")
    }
    for (inputs, field) in [
      (
        Fitting.Inputs.riserElbow(size: .threeAndQuarterByTen, corner: nil),
        Fitting.Issue.Field.riserCorner
      ),
      (.riserElbow(size: nil, corner: .radius), .riserSize),
    ] {
      #expect(
        try await client.evaluate(.init(pathType: .return, fittingID: "8P", inputs: inputs))
          == .unresolved([.init(.missingInput, field: field)]))
    }
  }

  @Test func unavailableVaneCellAndWrongInputFamiliesAreRejected() async throws {
    for path in [Fitting.PathType.supply, .return] {
      #expect(
        try await client.evaluate(
          .init(
            pathType: path, fittingID: "8H",
            inputs: .fourTurnOffset(heightLengthRatio: .oneHalf, turningVanes: true)))
          == .unresolved([.init(.unsupportedCombination, field: .turningVanes)]))
      for id in ["8D", "8E", "8F", "8G", "8H", "8I", "8J", "8K", "8N", "8P"] {
        // 8B/8C angle factors must not leak into other elbow or offset constructions.
        #expect(
          try await client.evaluate(
            .init(
              pathType: path, fittingID: .init(rawValue: id),
              inputs: .rectangularElbow(
                radiusRatio: .mitered, bendCategory: .square, angle: .degrees45)))
            == .unresolved([.init(.incompatibleInputs)]))
      }
    }
  }

  @Test func typedRatiosRejectIntermediateAndInclusiveRangeAssumptions() throws {
    for raw in [0.0, 1.5, 3, 5] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.OffsetLengthHeightRatio.self, from: Data(String(raw).utf8))
      }
    }
    for raw in [0.0, 0.75, 2.5] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.OffsetHeightLengthRatio.self, from: Data(String(raw).utf8))
      }
    }
    for raw in [-0.25, 0.75, 1.5] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.OffsetRadiusHeightRatio.self, from: Data(String(raw).utf8))
      }
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Fitting.RiserSize.self, from: Data(#""3.25x16""#.utf8))
    }
  }
}
