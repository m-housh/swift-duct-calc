import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingPannedReturnTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  // Independently transcribed source cells: viewer pages 30–31, printed page 175.
  @Test(arguments: [
    ("7A", [100.0, 150, 200], [25.0, 25, 25]),
    ("7B", [100.0, 150, 200], [10.0, 15, 25]),
    ("7C", [100.0, 200, 300, 400], [10.0, 30, 60, 110]),
    ("7D", [100.0, 150, 200], [20.0, 50, 90]),
    ("7E", [200.0, 400, 600, 800], [10.0, 30, 60, 110]),
  ])
  func originalRowsAndMidpoints(id: String, cfms: [Double], lengths: [Double]) async throws {
    for index in cfms.indices {
      let value = try await lookup(id, cfm: cfms[index])
      #expect(value.equivalentLengthFeet == lengths[index])
      #expect(value.airflowSelection == .init(submittedCFM: cfms[index], selectedCFM: cfms[index]))
      #expect(value.airflowSelection?.wasRounded == false)
      #expect(value.conditions.referenceVelocityFPM == 700)
      #expect(value.conditions.frictionRateIWCPer100Feet == 0.08)
    }
    for index in 1..<cfms.count {
      let midpoint = (cfms[index - 1] + cfms[index]) / 2
      for cfm in [midpoint.nextDown, midpoint, midpoint.nextUp] {
        let selectedIndex = cfm < midpoint ? index - 1 : index
        let value = try await lookup(id, cfm: cfm)
        #expect(value.equivalentLengthFeet == lengths[selectedIndex])
        #expect(
          value.airflowSelection == .init(submittedCFM: cfm, selectedCFM: cfms[selectedIndex]))
        #expect(value.airflowSelection?.wasRounded == true)
      }
    }
  }

  @Test(arguments: [
    ("7A", 100.0, 200.0), ("7B", 100, 200), ("7C", 100, 400),
    ("7D", 100, 200), ("7E", 200, 800),
  ])
  func boundsApplyBeforeRounding(id: String, minimum: Double, maximum: Double) async throws {
    for cfm in [minimum.nextDown, maximum.nextUp] {
      let result = try await client.evaluate(
        .init(
          pathType: .return, fittingID: .init(rawValue: id),
          inputs: .pannedReturn(airflowCFM: cfm, mergingFlow: false)))
      #expect(result == .unresolved([.init(.unsupportedAirflow, field: .airflowCFM)]))
    }
    _ = try await lookup(id, cfm: minimum)
    _ = try await lookup(id, cfm: maximum)
  }

  @Test func invalidInputsAndEligibility() async throws {
    let cases: [(Double?, Fitting.Issue.Code)] = [
      (nil, .missingInput), (.nan, .nonfiniteInput), (.infinity, .nonfiniteInput),
      (-.infinity, .nonfiniteInput), (0, .nonpositiveAirflow), (-100, .nonpositiveAirflow),
    ]
    for (cfm, code) in cases {
      let result = try await client.evaluate(
        .init(
          pathType: .return, fittingID: "7C",
          inputs: .pannedReturn(airflowCFM: cfm, mergingFlow: false)))
      #expect(result == .unresolved([.init(code, field: .airflowCFM)]))
    }
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: "7C",
          inputs: .pannedReturn(airflowCFM: 200, mergingFlow: false)))
        == .unresolved([.init(.ineligiblePathType)]))
    #expect(
      try await client.evaluate(.init(pathType: .return, fittingID: "7A", inputs: .fixed))
        == .unresolved([.init(.incompatibleInputs)]))
    for id in ["7A", "7B", "7D", "7E"] {
      #expect(
        try await client.evaluate(
          .init(
            pathType: .return, fittingID: .init(rawValue: id),
            inputs: .pannedReturn(airflowCFM: 200, mergingFlow: true)))
          == .unresolved([.init(.unsupportedCombination, field: .mergingFlow)]))
    }
  }

  @Test(arguments: [(100.0, 50.0), (200, 70), (249, 70), (250, 100), (300, 100), (400, 150)])
  func mergingFlowAddsOnce(cfm: Double, feet: Double) async throws {
    let value = try await lookup("7C", cfm: cfm, merging: true)
    #expect(value.equivalentLengthFeet == feet)
    #expect(value.components.count == 2)
    #expect(value.components.last == .init(ruleKey: "7C:merging-flow", equivalentLengthFeet: 40))
    #expect(value.components.reduce(0) { $0 + $1.equivalentLengthFeet } == feet)
    #expect(try await lookup("7C", cfm: cfm).equivalentLengthFeet == feet - 40)
  }

  @Test func snapshotPreservesRoundingAndAdjustment() async throws {
    let value = try await lookup("7C", cfm: 250, merging: true)
    #expect(value.inputs == .pannedReturn(airflowCFM: 250, mergingFlow: true))
    #expect(value.airflowSelection == .init(submittedCFM: 250, selectedCFM: 300))
    #expect(value.airflowSelection?.wasRounded == true)
    #expect(value.ruleRevision == "7C-v1")
    #expect(
      try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(value)) == value
    )
    // Existing snapshots have no airflow selection field.
    let fixed = try await client.evaluate(
      .init(pathType: .return, fittingID: "10G", inputs: .fixed))
    guard case .resolved(let oldValue) = fixed else {
      Issue.record("Expected fixed result")
      return
    }
    #expect(oldValue.airflowSelection == nil)
    #expect(
      try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(oldValue))
        == oldValue)
  }

  @Test func definitionsAndAlternateViewsShareIdentity() async throws {
    let definitions = try await client.fittings(.init(pathType: .return, groupID: .pannedReturns))
    #expect(definitions.map(\.id) == ["7A", "7B", "7C", "7D", "7E"])
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    var artworkCount = 0
    for definition in definitions {
      let rows: [Double] =
        switch definition.id.rawValue {
        case "7C": [100, 200, 300, 400]
        case "7E": [200, 400, 600, 800]
        default: [100, 150, 200]
        }
      #expect(
        definition.inputRequirement
          == .pannedReturn(airflowRows: rows, supportsMergingFlow: definition.id == "7C"))
      #expect(definition.defaultInputs == .pannedReturn(airflowCFM: nil, mergingFlow: false))
      #expect(
        try await client.resolveReference(.init(code: definition.id.rawValue, pathType: .return))
          == .recognized(
            .init(
              code: .init(rawValue: definition.id.rawValue), groupID: .pannedReturns,
              fittingIDs: [definition.id])))
      for view in definition.availableViews {
        guard
          case .available(let art) = try await client.artwork(
            .init(fittingID: definition.id, view: view))
        else {
          Issue.record("Expected declared artwork view")
          continue
        }
        #expect(art.view == view)
        let svg = try String(
          contentsOf: root.appendingPathComponent("Public" + art.publicPath), encoding: .utf8)
        #expect(svg.contains("<svg"))
        artworkCount += 1
      }
    }
    #expect(artworkCount == 9)
    #expect(
      definitions.first { $0.id == "7C" }?.availableViews == [
        .individual, .assembly, .assemblyMerging,
      ])
    #expect(
      try await client.artwork(.init(fittingID: "7D", view: .assembly))
        == .unavailable(.unsupportedView))
    #expect(
      try await client.artwork(.init(fittingID: "7A", view: .assemblyMerging))
        == .unavailable(.unsupportedView))
    #expect(
      try await client.artwork(.init(fittingID: "7C", shape: .round, view: .assembly))
        == .unavailable(.unsupportedShape))
  }

  private func lookup(_ id: String, cfm: Double, merging: Bool = false) async throws
    -> Fitting.Calculation
  {
    let result = try await client.evaluate(
      .init(
        pathType: .return, fittingID: .init(rawValue: id),
        inputs: .pannedReturn(airflowCFM: cfm, mergingFlow: merging)))
    guard case .resolved(let value) = result else {
      throw LookupError.unresolved
    }
    return value
  }

  enum LookupError: Error { case unresolved }
}
