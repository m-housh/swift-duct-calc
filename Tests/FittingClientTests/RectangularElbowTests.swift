import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingRectangularElbowTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  // Source viewer page 33: hard bend, H/W = 1, easy bend, in that order.
  @Test(arguments: [
    ("8B", Fitting.RectangularElbowRadiusRatio.mitered, [90.0, 75, 65]),
    ("8B", .oneQuarter, [35.0, 30, 25]),
    ("8B", .oneHalfOrGreater, [20.0, 15, 10]),
    ("8C", .mitered, [30.0, 25, 40]),
    ("8C", .oneQuarter, [10.0, 10, 10]),
    ("8C", .oneHalfOrGreater, [5.0, 5, 5]),
  ])
  func sourceCellsAndAngles(id: String, ratio: Fitting.RectangularElbowRadiusRatio, feet: [Double])
    async throws
  {
    let angles: [(Fitting.ElbowAngle, Double)] = [
      (.degrees30, 0.45), (.degrees45, 0.60), (.degrees60, 0.78), (.degrees90, 1),
    ]
    for (category, base) in zip(Fitting.ElbowBendCategory.allCases, feet) {
      for (angle, multiplier) in angles {
        for path in [Fitting.PathType.supply, .return] {
          let inputs = Fitting.Inputs.rectangularElbow(
            radiusRatio: ratio, bendCategory: category, angle: angle)
          let value = try await lookup(id, inputs: inputs, path: path)
          #expect(abs(value.equivalentLengthFeet - base * multiplier) < 1e-10)
          #expect(value.inputs == inputs)
          #expect(value.sourceCode?.rawValue == id)
          #expect(value.components.count == 1)
          #expect(value.components[0].equivalentLengthFeet == value.equivalentLengthFeet)
          #expect(
            value.components[0].ruleKey.hasSuffix(":\(category.rawValue):angle:\(angle.rawValue)"))
          #expect(value.conditions.referenceVelocityFPM == 900)
          #expect(value.conditions.frictionRateIWCPer100Feet == 0.08)
        }
      }
    }
  }

  @Test(arguments: ["8B", "8C"])
  func pickerDefaultsAndReference(id: String) async throws {
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .elbows))
    let definition = try #require(definitions.first { $0.id.rawValue == id })
    #expect(
      definition.inputRequirement
        == .rectangularElbow(
          radiusRatios: [.mitered, .oneQuarter, .oneHalfOrGreater],
          bendCategories: [.hardBend, .square, .easyBend],
          angles: [.degrees30, .degrees45, .degrees60, .degrees90]))
    #expect(
      definition.defaultInputs
        == .rectangularElbow(radiusRatio: .mitered, bendCategory: nil, angle: .degrees90))
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: definition.id,
          inputs: definition.defaultInputs))
        == .unresolved([.init(.missingInput, field: .bendCategory)]))
    #expect(
      try await client.resolveReference(.init(code: id, pathType: .return))
        == .recognized(
          .init(code: .init(rawValue: id), groupID: .elbows, fittingIDs: [definition.id])))
    guard case .available(let artwork) = try await client.artwork(.init(fittingID: definition.id))
    else {
      Issue.record("Missing elbow artwork")
      return
    }
    #expect(artwork.publicPath == "/images/fittings/group-8/\(id).svg")
    #expect(
      try await client.artwork(.init(fittingID: definition.id, shape: .round))
        == .unavailable(.unsupportedShape))
  }

  @Test func incompleteAndIncompatibleInputs() async throws {
    let cases: [(Fitting.Inputs, [Fitting.Issue])] = [
      (
        .rectangularElbow(radiusRatio: nil, bendCategory: nil, angle: nil),
        [
          .init(.missingInput, field: .radiusRatio), .init(.missingInput, field: .bendCategory),
          .init(.missingInput, field: .elbowAngle),
        ]
      ),
      (
        .rectangularElbow(radiusRatio: nil, bendCategory: .square, angle: .degrees90),
        [
          .init(.missingInput, field: .radiusRatio)
        ]
      ),
      (
        .rectangularElbow(radiusRatio: .mitered, bendCategory: .square, angle: nil),
        [
          .init(.missingInput, field: .elbowAngle)
        ]
      ),
      (.roundElbow(radiusRatio: .one, angle: .degrees90), [.init(.incompatibleInputs)]),
      (.radiusWidth(radiusInches: 0, widthInches: 10), [.init(.incompatibleInputs)]),
    ]
    for id in ["8B", "8C"] {
      for (inputs, issues) in cases {
        #expect(
          try await client.evaluate(
            .init(pathType: .return, fittingID: .init(rawValue: id), inputs: inputs))
            == .unresolved(issues))
      }
      for angle in [
        Fitting.ElbowAngle.degrees20, .degrees75, .degrees110, .degrees130, .degrees150,
      ] {
        #expect(
          try await client.evaluate(
            .init(
              pathType: .return, fittingID: .init(rawValue: id),
              inputs: .rectangularElbow(radiusRatio: .mitered, bendCategory: .square, angle: angle))
          )
            == .unresolved([.init(.unsupportedCombination, field: .elbowAngle)]))
      }
    }
  }

  @Test func fractionalSnapshotAndTypedCategories() async throws {
    let value = try await lookup(
      "8B",
      inputs: .rectangularElbow(
        radiusRatio: .mitered, bendCategory: .square, angle: .degrees30))
    #expect(value.equivalentLengthFeet == 33.75)
    #expect(value.ruleRevision == "8B-v1")
    #expect(
      try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(value)) == value
    )
    #expect(
      Fitting.RectangularElbowRadiusRatio.allCases.map(\.label)
        == ["Mitered (R/W = 0)", "0.25", "0.5 or greater"])
    #expect(
      Fitting.ElbowBendCategory.allCases.map(\.label)
        == ["Hard bend", "Square cross-section (H/W = 1)", "Easy bend"])
    for raw in [-1.0, 0.125, 0.75, 1.0] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(
          Fitting.RectangularElbowRadiusRatio.self, from: Data(String(raw).utf8))
      }
    }
    #expect(
      try JSONDecoder().decode(Fitting.RectangularElbowRadiusRatio.self, from: Data("0".utf8))
        == .mitered)
    #expect(
      try JSONDecoder().decode(Fitting.RectangularElbowRadiusRatio.self, from: Data("0.5".utf8))
        == .oneHalfOrGreater)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Fitting.ElbowBendCategory.self, from: Data("\"unknown\"".utf8))
    }
  }

  private func lookup(_ id: String, inputs: Fitting.Inputs, path: Fitting.PathType = .supply)
    async throws -> Fitting.Calculation
  {
    let result = try await client.evaluate(
      .init(pathType: path, fittingID: .init(rawValue: id), inputs: inputs))
    guard case .resolved(let value) = result else { throw LookupError.unresolved }
    return value
  }

  enum LookupError: Error { case unresolved }
}
