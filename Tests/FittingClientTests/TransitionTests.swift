import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingTransitionTests {
  let client: FittingClient

  init() async throws { client = try await loadBundledFittingClient() }

  // Printed pages 182–183: slope rows 1:1, 2:1, 4:1; larger/smaller area columns 2 and 4.
  @Test(arguments: [
    ("12A", [[20.0, 40], [20, 40], [20, 30]]), ("12B", [[20, 40]]),
    ("12C", [[20, 40], [20, 40], [20, 30]]), ("12D", [[20, 40], [20, 40], [20, 30]]),
    ("12F", [[20, 40], [20, 40], [15, 30]]), ("12G", [[20, 40]]),
    ("12H", [[20, 40], [20, 40], [15, 25]]), ("12I", [[20, 35], [15, 25], [10, 10]]),
    ("12J", [[10, 10], [5, 5], [5, 5]]), ("12K", [[25, 25]]),
    ("12L", [[10, 10], [5, 5], [5, 5]]), ("12M", [[10, 10], [5, 5], [5, 5]]),
    ("12O", [[10, 10], [5, 5], [5, 5]]), ("12P", [[30, 30]]),
    ("12Q", [[10, 10], [5, 5], [5, 5]]), ("12R", [[5, 5], [5, 5], [5, 5]]),
  ])
  func sourceSlopeAndAreaCells(id: String, values: [[Double]]) async throws {
    let slopes: [Fitting.TransitionSlope] =
      values.count == 1 ? [.abrupt] : [.oneToOne, .twoToOne, .fourToOne]
    for (slope, row) in zip(slopes, values) {
      for (ratio, feet) in zip(Fitting.TransitionAreaRatio.allCases, row) {
        try await check(id, .transition(slope: slope, areaRatio: ratio), feet)
      }
    }
  }

  @Test(arguments: [("12E", 25.0), ("12N", 10), ("12S", 30), ("12T", 30), ("12U", 25), ("12V", 30)])
  func fixedAdapters(id: String, feet: Double) async throws {
    try await check(id, .fixed, feet)
  }

  @Test func plenumKeepsInletAndOutletAxesDistinct() async throws {
    // Printed page 184: outlet rows, inlet columns. This is not a symmetric table.
    let values: [[Double]] = [
      [40, 40, 35, 35], [55, 55, 50, 50], [70, 70, 70, 65], [90, 90, 90, 85],
    ]
    for (outlet, row) in zip(Fitting.TransitionVelocity.allCases, values) {
      for (inlet, feet) in zip(Fitting.TransitionVelocity.allCases, row) {
        try await check("12W", .plenumPassage(inletVelocity: inlet, outletVelocity: outlet), feet)
      }
    }
  }

  @Test func squeezeRetainsPressureAsAConditionRatherThanLength() async throws {
    let values: [[Double]] = [[65, 245], [90, 330], [115, 430], [145, 545]]
    let pressures = [[0.12, 0.52], [0.16, 0.71], [0.20, 0.92], [0.26, 1.17]]
    for (index, velocity) in Fitting.TransitionVelocity.allCases.enumerated() {
      for (column, ratio) in Fitting.TransitionAreaRatio.allCases.enumerated() {
        try await check(
          "12X", .abruptSqueeze(upstreamVelocity: velocity, areaRatio: ratio),
          values[index][column], pressure: pressures[index][column])
      }
    }
  }

  @Test func incompleteSelectionsAndUnsupportedCombinations() async throws {
    let cases: [(String, Fitting.Inputs, [Fitting.Issue])] = [
      (
        "12A", .transition(slope: nil, areaRatio: nil),
        [.init(.missingInput, field: .transitionSlope), .init(.missingInput, field: .areaRatio)]
      ),
      (
        "12B", .transition(slope: nil, areaRatio: .two),
        [.init(.missingInput, field: .transitionSlope)]
      ),
      ("12A", .transition(slope: .abrupt, areaRatio: .two), [.init(.unsupportedCombination)]),
      ("12B", .transition(slope: .oneToOne, areaRatio: .two), [.init(.unsupportedCombination)]),
      (
        "12W", .plenumPassage(inletVelocity: nil, outletVelocity: nil),
        [.init(.missingInput, field: .inletVelocity), .init(.missingInput, field: .outletVelocity)]
      ),
      (
        "12W", .plenumPassage(inletVelocity: .fpm600, outletVelocity: nil),
        [.init(.missingInput, field: .outletVelocity)]
      ),
      (
        "12X", .abruptSqueeze(upstreamVelocity: nil, areaRatio: nil),
        [.init(.missingInput, field: .upstreamVelocity), .init(.missingInput, field: .areaRatio)]
      ),
      (
        "12X", .abruptSqueeze(upstreamVelocity: nil, areaRatio: .two),
        [.init(.missingInput, field: .upstreamVelocity)]
      ),
      (
        "12W", .abruptSqueeze(upstreamVelocity: .fpm900, areaRatio: .two),
        [.init(.incompatibleInputs)]
      ),
      (
        "12X", .plenumPassage(inletVelocity: .fpm900, outletVelocity: .fpm900),
        [.init(.incompatibleInputs)]
      ),
    ]
    for (id, inputs, issues) in cases {
      #expect(
        try await client.evaluate(
          .init(pathType: .supply, fittingID: .init(rawValue: id), inputs: inputs))
          == .unresolved(issues))
    }
    for velocity in [599, 650, 901] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.TransitionVelocity.self, from: Data(String(velocity).utf8))
      }
    }
    for ratio in [1.0, 2.5, 3, 5] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Fitting.TransitionAreaRatio.self, from: Data(String(ratio).utf8))
      }
    }
  }

  @Test func pickerRequirementsAndDefaults() async throws {
    let definitions = try await client.fittings(.init(pathType: .return, groupID: .transitions))
    #expect(definitions.count == 24)
    for definition in definitions {
      switch definition.inputRequirement {
      case .transition(let slopes, let ratios):
        let abrupt = ["12B", "12G", "12K", "12P"].contains(definition.id.rawValue)
        #expect(slopes == (abrupt ? [.abrupt] : [.oneToOne, .twoToOne, .fourToOne]))
        #expect(ratios == [.two, .four])
        #expect(
          definition.defaultInputs == .transition(slope: abrupt ? .abrupt : nil, areaRatio: nil))
      case .plenumPassage(let inlet, let outlet):
        #expect(inlet == Fitting.TransitionVelocity.allCases && outlet == inlet)
        #expect(definition.defaultInputs == .plenumPassage(inletVelocity: nil, outletVelocity: nil))
        #expect(definition.conditions.referenceVelocityFPM == nil)
      case .abruptSqueeze(let velocities, let ratios):
        #expect(velocities == Fitting.TransitionVelocity.allCases && ratios == [.two, .four])
        #expect(definition.defaultInputs == .abruptSqueeze(upstreamVelocity: nil, areaRatio: nil))
        #expect(definition.conditions.referenceVelocityFPM == nil)
      case .fixed: #expect(definition.defaultInputs == .fixed)
      default: Issue.record("Unexpected transition rule")
      }
      guard case .available = try await client.artwork(.init(fittingID: definition.id)) else {
        Issue.record("Artwork must be available before table selections")
        continue
      }
    }
  }

  private func check(
    _ id: String, _ inputs: Fitting.Inputs, _ feet: Double, pressure: Double? = nil
  ) async throws {
    for path in [Fitting.PathType.supply, .return] {
      guard
        case .resolved(let value) = try await client.evaluate(
          .init(
            pathType: path,
            fittingID: .init(rawValue: id), inputs: inputs))
      else {
        Issue.record("Expected \(id) cell")
        continue
      }
      #expect(value.equivalentLengthFeet == feet)
      #expect(value.components.count == 1 && value.components[0].equivalentLengthFeet == feet)
      #expect(value.inputs == inputs)
      #expect(value.sourceCode?.rawValue == id)
      #expect(value.minimumUpstreamStaticPressureIWC == pressure)
      if case .abruptSqueeze(let velocity, _) = inputs {
        #expect(value.conditions.referenceVelocityFPM == velocity?.rawValue)
      } else {
        #expect(value.conditions.referenceVelocityFPM == (id == "12W" ? nil : 900))
      }
      #expect(
        try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(value))
          == value)
    }
  }
}
