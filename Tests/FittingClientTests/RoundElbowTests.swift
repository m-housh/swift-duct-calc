import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingRoundElbowTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  // Source 8A, viewer page 32: distinct construction columns, including the legacy-swapped cells.
  @Test(arguments: [
    ("8A-smooth", [20.0, 15, 10]),
    ("8A-4-or-5-piece", [30.0, 20, 15]),
    ("8A-3-piece", [35.0, 25, 20]),
  ])
  func publishedRadiusRows(id: String, lengths: [Double]) async throws {
    for (ratio, feet) in zip(Fitting.RoundElbowRadiusRatio.allCases, lengths) {
      for path in [Fitting.PathType.supply, .return] {
        let value = try await lookup(id, ratio: ratio, angle: .degrees90, path: path)
        #expect(value.equivalentLengthFeet == feet)
        #expect(value.sourceCode == "8A")
        #expect(value.conditions.referenceVelocityFPM == 900)
        #expect(value.conditions.frictionRateIWCPer100Feet == 0.08)
      }
    }
  }

  // Expected lengths calculated independently from each printed base row and angle factor.
  @Test(arguments: [
    (Fitting.ElbowAngle.degrees20, [6.2, 4.65, 3.1]),
    (.degrees30, [9.0, 6.75, 4.5]),
    (.degrees45, [12.0, 9, 6]),
    (.degrees60, [15.6, 11.7, 7.8]),
    (.degrees75, [18.0, 13.5, 9]),
    (.degrees90, [20.0, 15, 10]),
    (.degrees110, [22.6, 16.95, 11.3]),
    (.degrees130, [24.0, 18, 12]),
    (.degrees150, [25.6, 19.2, 12.8]),
  ])
  func smoothAngleValues(angle: Fitting.ElbowAngle, lengths: [Double]) async throws {
    for (ratio, feet) in zip(Fitting.RoundElbowRadiusRatio.allCases, lengths) {
      let value = try await lookup("8A-smooth", ratio: ratio, angle: angle)
      #expect(abs(value.equivalentLengthFeet - feet) < 1e-10)
      #expect(value.components.count == 1)
      #expect(value.components[0].equivalentLengthFeet == value.equivalentLengthFeet)
      #expect(value.components[0].ruleKey.hasSuffix(":angle:\(angle.rawValue)"))
      #expect(value.inputs == .roundElbow(radiusRatio: ratio, angle: angle))
      #expect(
        try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(value))
          == value)
    }
  }

  @Test func pickerChoicesAndDefaults() async throws {
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .elbows))
    #expect(definitions.map(\.id) == ["8A-smooth", "8A-4-or-5-piece", "8A-3-piece"])
    for definition in definitions {
      #expect(
        definition.inputRequirement
          == .roundElbow(
            radiusRatios: [.threeQuarters, .one, .oneAndHalfOrGreater],
            angles: definition.id == "8A-smooth" ? Fitting.ElbowAngle.allCases : [.degrees90]))
      #expect(definition.defaultInputs == .roundElbow(radiusRatio: nil, angle: .degrees90))
      #expect(
        try await client.evaluate(
          .init(
            pathType: .supply, fittingID: definition.id,
            inputs: definition.defaultInputs))
          == .unresolved([.init(.missingInput, field: .radiusRatio)]))
    }
    #expect(
      Fitting.RoundElbowRadiusRatio.allCases.map(\.label) == ["0.75", "1.0", "1.5 or greater"])
    #expect(Fitting.ElbowAngle.degrees90.label == "90°")
    #expect(
      try await client.resolveReference(.init(code: "8a", pathType: .return))
        == .recognized(.init(code: "8A", groupID: .elbows, fittingIDs: definitions.map(\.id))))
  }

  @Test func arbitraryValuesCannotDecodeAsChoices() throws {
    for value in [0.74, 1.2, 1.25, 2.0] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.RoundElbowRadiusRatio.self, from: Data(String(value).utf8))
      }
    }
    for value in [0, 25, 89, 180] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.ElbowAngle.self, from: Data(String(value).utf8))
      }
    }
    // The inclusive category has one stable encoded identity, even when the physical R/D is larger.
    #expect(
      try JSONDecoder().decode(Fitting.RoundElbowRadiusRatio.self, from: Data("1.5".utf8))
        == .oneAndHalfOrGreater)
  }

  @Test func incompleteAndIncompatibleInputs() async throws {
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: "8A-smooth",
          inputs: .roundElbow(radiusRatio: nil, angle: nil)))
        == .unresolved([
          .init(.missingInput, field: .radiusRatio), .init(.missingInput, field: .elbowAngle),
        ]))
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: "8A-smooth",
          inputs: .roundElbow(radiusRatio: .one, angle: nil)))
        == .unresolved([.init(.missingInput, field: .elbowAngle)]))
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: "8A-smooth",
          inputs: .radiusWidth(radiusInches: 10, widthInches: 10)))
        == .unresolved([.init(.incompatibleInputs)]))
    for id in ["8A-4-or-5-piece", "8A-3-piece"] {
      for angle in Fitting.ElbowAngle.allCases where angle != .degrees90 {
        #expect(
          try await client.evaluate(
            .init(
              pathType: .supply, fittingID: .init(rawValue: id),
              inputs: .roundElbow(radiusRatio: .one, angle: angle)))
            == .unresolved([.init(.unsupportedCombination, field: .elbowAngle)]))
      }
    }
  }

  private func lookup(
    _ id: String, ratio: Fitting.RoundElbowRadiusRatio, angle: Fitting.ElbowAngle,
    path: Fitting.PathType = .supply
  ) async throws -> Fitting.Calculation {
    let result = try await client.evaluate(
      .init(
        pathType: path, fittingID: .init(rawValue: id),
        inputs: .roundElbow(radiusRatio: ratio, angle: angle)))
    guard case .resolved(let value) = result else { throw LookupError.unresolved }
    return value
  }

  enum LookupError: Error { case unresolved }
}
