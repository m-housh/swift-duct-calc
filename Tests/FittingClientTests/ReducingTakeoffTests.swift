import FittingClient
import Foundation
import ManualDCore
import Testing

struct FittingReducingTakeoffTests {
  let client: FittingClient

  init() async throws { client = try await loadBundledFittingClient() }

  // Independently checked against viewer pages 10–13. 3U uses its specific detail table.
  @Test(arguments: [
    ("3A", 15.0), ("3B", 30), ("3C", 20),
    ("3D-full", 35), ("3D-tight", 55), ("3D-mitered", 110), ("3E", 30),
    ("3F-full", 50), ("3F-tight", 70), ("3F-mitered", 125), ("3G", 35), ("3H", 35),
    ("3I", 15), ("3J-full", 35), ("3J-tight", 55), ("3J-mitered", 110),
    ("3K", 20), ("3L", 30), ("3M", 25), ("3N", 40),
    ("3S-full", 15), ("3S-tight", 35), ("3S-mitered", 90), ("3T", 10),
    ("3U-mitered-vanes", 10), ("3U-mitered-no-vanes", 80), ("3V", 30), ("3W", 30),
  ])
  func fixedSourceAssemblies(id: String, feet: Double) async throws {
    let request = Fitting.EvaluationRequest(
      pathType: .supply, fittingID: .init(rawValue: id), inputs: .fixed)
    guard case .resolved(let value) = try await client.evaluate(request) else {
      Issue.record("Expected source assembly \(id)")
      return
    }
    #expect(value.equivalentLengthFeet == feet)
    #expect(value.sourceCode?.rawValue == String(id.prefix(2)))
    #expect(value.components.count == 1)
    #expect(
      try await client.evaluate(
        .init(pathType: .return, fittingID: request.fittingID, inputs: .fixed))
        == .unresolved([.init(.ineligiblePathType)]))
    #expect(
      try await client.evaluate(
        .init(
          pathType: .supply, fittingID: request.fittingID,
          inputs: .easedTakeoff(buttedSleeve: true))) == .unresolved([.init(.incompatibleInputs)]))
  }

  @Test(arguments: [("3O", 20.0), ("3P", 50), ("3Q", 35), ("3R", 20)])
  func buttedSleeveAddsFifteenOnce(id: String, baseFeet: Double) async throws {
    for butted in [false, true] {
      let inputs = Fitting.Inputs.easedTakeoff(buttedSleeve: butted)
      guard
        case .resolved(let value) = try await client.evaluate(
          .init(
            pathType: .supply,
            fittingID: .init(rawValue: id), inputs: inputs))
      else {
        Issue.record("Expected eased takeoff")
        continue
      }
      #expect(value.equivalentLengthFeet == baseFeet + (butted ? 15 : 0))
      #expect(value.components.count == (butted ? 2 : 1))
      #expect(value.components[0].equivalentLengthFeet == baseFeet)
      if butted { #expect(value.components[1].equivalentLengthFeet == 15) }
      #expect(value.inputs == inputs)
      #expect(
        try JSONDecoder().decode(Fitting.Calculation.self, from: JSONEncoder().encode(value))
          == value)
      #expect(
        try await client.evaluate(
          .init(pathType: .return, fittingID: value.fittingID, inputs: inputs))
          == .unresolved([.init(.ineligiblePathType)]))
    }
  }

  @Test func completeInventoryDefaultsAndSourceIdentity() async throws {
    let definitions = try await client.fittings(
      .init(pathType: .supply, groupID: .reducingTrunkTakeoffs))
    #expect(definitions.count == 32)
    for definition in definitions {
      let sleeve = ["3O", "3P", "3Q", "3R"].contains(definition.id.rawValue)
      #expect(definition.defaultInputs == (sleeve ? .easedTakeoff(buttedSleeve: false) : .fixed))
      #expect(definition.inputRequirement == (sleeve ? .easedTakeoff : .fixed))
    }
    #expect(
      try await client.resolveReference(.init(code: "3u", pathType: .supply))
        == .recognized(
          .init(
            code: "3U", groupID: .reducingTrunkTakeoffs,
            fittingIDs: ["3U-mitered-vanes", "3U-mitered-no-vanes"])))
    #expect(
      try await client.resolveReference(.init(code: "3j", pathType: .supply))
        == .recognized(
          .init(
            code: "3J", groupID: .reducingTrunkTakeoffs,
            fittingIDs: ["3J-full", "3J-tight", "3J-mitered"])))
  }
}
