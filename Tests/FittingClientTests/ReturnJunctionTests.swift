import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingReturnJunctionTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  // Source cells from viewer pages 25 and 27, independently transcribed from the PDF.
  @Test(arguments: [
    (
      "6A", [0.4, 0.5, 0.6, 0.7, 0.8, 1.0], [10.0, 25, 40, 60, 75, 75], [10.0, 25, 25, 25, 25, nil]
    ),
    (
      "6B", [0.4, 0.5, 0.6, 0.7, 0.8, 1.0], [10.0, 40, 40, 75, 110, 110],
      [10.0, 25, 25, 25, 25, nil]
    ),
    (
      "6C", [0.4, 0.5, 0.6, 0.7, 0.8, 1.0], [10.0, 30, 50, 75, 115, 115],
      [10.0, 25, 25, 25, 25, nil]
    ),
    (
      "6D", [0.1, 0.2, 0.3, 0.4, 0.6, 0.8, 1.0], [10.0, 15, 20, 30, 30, 30, 30],
      [5.0, 5, 5, 5, 5, 5, nil]
    ),
    (
      "6E", [0.1, 0.2, 0.3, 0.4, 0.5, 0.8, 1.0], [15.0, 30, 40, 40, 40, 40, 40],
      [10.0, 10, 10, 10, 25, 25, nil]
    ),
  ])
  func originalTableValues(id: String, ratios: [Double], branch: [Double], trunk: [Double?])
    async throws
  {
    for index in ratios.indices {
      let value = try await lookup(id, branchCFM: ratios[index], totalCFM: 1)
      #expect(value.branch.equivalentLengthFeet == branch[index])
      #expect(value.trunk?.equivalentLengthFeet == trunk[index])
      #expect(
        value.ratioSelection
          == .init(
            calculatedRatio: ratios[index], selectedRatio: ratios[index], reason: .exact))
      #expect(value.conditions.referenceVelocityFPM == 700)
    }
  }

  @Test(arguments: [(0.74, 0.7, 60.0), (0.75, 0.8, 75.0)])
  func requestedRoundingExamples(ratio: Double, selected: Double, branchFeet: Double) async throws {
    let value = try await lookup("6A", branchCFM: ratio * 100, totalCFM: 100)
    #expect(value.branch.equivalentLengthFeet == branchFeet)
    #expect(value.trunk?.equivalentLengthFeet == 25)
    #expect(
      value.ratioSelection
        == .init(calculatedRatio: ratio, selectedRatio: selected, reason: .rounded))
    #expect(value.inputs == .returnJunction(branchCFM: ratio * 100, totalCFM: 100))
  }

  @Test(arguments: [
    ("6A", 0.45, 0.4, 0.5), ("6A", 0.55, 0.5, 0.6), ("6A", 0.65, 0.6, 0.7),
    ("6A", 0.75, 0.7, 0.8), ("6A", 0.9, 0.8, 1.0),
    ("6D", 0.15, 0.1, 0.2), ("6D", 0.25, 0.2, 0.3), ("6D", 0.35, 0.3, 0.4),
    ("6D", 0.5, 0.4, 0.6), ("6D", 0.7, 0.6, 0.8), ("6D", 0.9, 0.8, 1.0),
    ("6E", 0.15, 0.1, 0.2), ("6E", 0.25, 0.2, 0.3), ("6E", 0.35, 0.3, 0.4),
    ("6E", 0.45, 0.4, 0.5), ("6E", 0.65, 0.5, 0.8), ("6E", 0.9, 0.8, 1.0),
  ])
  func midpointTiesSelectHigherPublishedRow(
    id: String, midpoint: Double, lower: Double, upper: Double
  ) async throws {
    for (ratio, expected) in [
      (midpoint.nextDown, lower), (midpoint, upper), (midpoint.nextUp, upper),
    ] {
      let value = try await lookup(id, branchCFM: ratio, totalCFM: 1)
      #expect(value.ratioSelection.selectedRatio == expected)
      #expect(value.ratioSelection.reason == .rounded)
    }
  }

  @Test(arguments: ["6A", "6B", "6C"])
  func lowRatioRangeIsNotMarkedAsRounding(id: String) async throws {
    for ratio in [0.01, 0.1, 0.4.nextDown] {
      let value = try await lookup(id, branchCFM: ratio, totalCFM: 1)
      #expect(value.branch.equivalentLengthFeet == 10)
      #expect(value.trunk?.equivalentLengthFeet == 10)
      #expect(
        value.ratioSelection
          == .init(calculatedRatio: ratio, selectedRatio: 0.4, reason: .sourceRange))
    }
  }

  @Test func invalidFlowsAndUnsupportedRangesStayUnresolved() async throws {
    for (inputs, issues) in [
      (
        Fitting.Inputs.returnJunction(branchCFM: nil, totalCFM: nil),
        [Fitting.Issue(.missingInput, field: .branchCFM), .init(.missingInput, field: .totalCFM)]
      ),
      (
        .returnJunction(branchCFM: 0, totalCFM: -1),
        [
          .init(.nonpositiveAirflow, field: .branchCFM),
          .init(.nonpositiveAirflow, field: .totalCFM),
        ]
      ),
      (
        .returnJunction(branchCFM: .nan, totalCFM: .infinity),
        [.init(.nonfiniteInput, field: .branchCFM), .init(.nonfiniteInput, field: .totalCFM)]
      ),
      (
        .returnJunction(branchCFM: 101, totalCFM: 100),
        [.init(.branchExceedsTotal, field: .branchCFM)]
      ),
      (
        .returnJunction(branchCFM: .leastNonzeroMagnitude, totalCFM: .greatestFiniteMagnitude),
        [.init(.unsupportedRatio)]
      ),
      (.fixed, [.init(.incompatibleInputs)]),
      (.junction(path: .branch), [.init(.incompatibleInputs)]),
    ] {
      let value = try await client.evaluate(
        .init(pathType: .return, fittingID: "6A", inputs: inputs))
      #expect(value == .unresolved(issues))
    }
    for id in ["6D", "6E"] {
      let value = try await client.evaluate(
        .init(
          pathType: .return, fittingID: Fitting.ID(rawValue: id),
          inputs: .returnJunction(branchCFM: 0.1.nextDown, totalCFM: 1)))
      #expect(value == .unresolved([.init(.unsupportedRatio)]))
    }
    let wrongPath = try await client.evaluate(
      .init(
        pathType: .supply, fittingID: "6A",
        inputs: .returnJunction(branchCFM: 50, totalCFM: 100)))
    #expect(wrongPath == .unresolved([.init(.ineligiblePathType)]))
  }

  @Test func selectedNACellRemainsUnavailableAndSnapshotRetainsBothColumns() async throws {
    for ratio in [0.75, 0.9, 1.0] {
      let value = try await lookup("6A", branchCFM: ratio, totalCFM: 1)
      #expect(value.branch.equivalentLengthFeet == 75)
      #expect(value.trunk?.equivalentLengthFeet == (ratio == 0.75 ? 25 : nil))
      let encoded = try JSONEncoder().encode(value)
      #expect(
        try JSONDecoder().decode(Fitting.ReturnJunctionCalculation.self, from: encoded) == value)
    }
    let value = try await lookup("6A", branchCFM: 75, totalCFM: 100)
    #expect(value.branch.ruleKey == "6A/0.8/branch")
    #expect(value.trunk?.ruleKey == "6A/0.8/trunk")
  }

  @Test func branchAndTrunkResultsSupportDistinctPathTotals() async throws {
    // Source topology on viewer page 26, using the user's table-row rounding policy.
    let r1 = try await lookup("6A", branchCFM: 177, totalCFM: 177)
    let r2 = try await lookup("6A", branchCFM: 530, totalCFM: 707)
    let r3 = try await lookup("6A", branchCFM: 235, totalCFM: 942)
    let trunk2 = try #require(r2.trunk).equivalentLengthFeet
    let trunk3 = try #require(r3.trunk).equivalentLengthFeet
    // Do not round the calculated ratio for display before selecting the table row.
    #expect(r2.ratioSelection.calculatedRatio == 530.0 / 707.0)
    #expect(r2.ratioSelection.selectedRatio == 0.7)
    #expect(r1.branch.equivalentLengthFeet + trunk2 + trunk3 == 110)
    #expect(r2.branch.equivalentLengthFeet + trunk3 == 70)
    #expect(r3.branch.equivalentLengthFeet == 10)
  }

  @Test func requirementsAndCoverage() async throws {
    let groups = try await client.groups(.return)
    #expect(groups.first { $0.id == .returnBranches }?.availableFittingCount == 16)
    let definitions = try await client.fittings(.init(pathType: .return, groupID: .returnBranches))
    let rectangular = try #require(definitions.first { $0.id == "6A" })
    #expect(
      rectangular.inputRequirement
        == .returnJunction(
          ratios: [0.4, 0.5, 0.6, 0.7, 0.8, 1], firstRowIncludesLowerRatios: true))
    #expect(rectangular.defaultInputs == .returnJunction(branchCFM: nil, totalCFM: nil))
    let round = try #require(definitions.first { $0.id == "6D" })
    #expect(
      round.inputRequirement
        == .returnJunction(
          ratios: [0.1, 0.2, 0.3, 0.4, 0.6, 0.8, 1], firstRowIncludesLowerRatios: false))
  }

  private func lookup(_ id: String, branchCFM: Double, totalCFM: Double) async throws
    -> Fitting.ReturnJunctionCalculation
  {
    let result = try await client.evaluate(
      .init(
        pathType: .return, fittingID: Fitting.ID(rawValue: id),
        inputs: .returnJunction(branchCFM: branchCFM, totalCFM: totalCFM)))
    guard case .resolvedReturnJunction(let value) = result else {
      Issue.record("Expected both return-junction columns for \(id), got \(result)")
      throw FixtureError.unresolved
    }
    return value
  }

  private enum FixtureError: Error { case unresolved }
}
