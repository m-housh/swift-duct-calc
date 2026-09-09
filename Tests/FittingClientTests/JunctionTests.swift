import FittingClient
import Foundation
import ManualDCore
import Testing

/// Values checked directly against the group 6, 9, and 10 reference pages.
struct FittingJunctionTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  @Test(arguments: [
    ("6F", 25.0), ("6G", 30.0), ("6H", 15.0), ("6I", 30.0), ("6J", 55.0),
    ("6K", 10.0), ("6L", 20.0), ("6M", 20.0), ("6N", 10.0), ("6O", 10.0), ("6P", 5.0),
    ("9K", 65.0), ("9L", 20.0), ("9M", 20.0), ("9N", 15.0), ("9O", 15.0),
    ("9P", 70.0), ("9Q", 55.0), ("9R", 35.0),
    ("10A", 75.0), ("10B", 10.0), ("10C", 10.0), ("10D", 25.0),
    ("10E", 25.0), ("10F", 35.0), ("10G", 75.0),
  ])
  func fixedSourceValues(id: String, expected: Double) async throws {
    let result = try await calculation(id, .fixed)
    #expect(result.equivalentLengthFeet == expected)
    #expect(result.conditions.referenceVelocityFPM == (id.hasPrefix("9") ? 900 : 700))
  }

  @Test(arguments: [
    ("9A", 80.0), ("9B", 80.0), ("9C", 80.0), ("9D", 75.0), ("9E", 50.0),
    ("9F", 45.0), ("9G", 35.0), ("9H", 100.0), ("9I", 85.0), ("9J", 25.0),
  ])
  func selectedJunctionPathUsesOnlyItsOwnLength(id: String, branchFeet: Double) async throws {
    for path in Fitting.JunctionPath.allCases {
      let inputs = Fitting.Inputs.junction(path: path)
      let result = try await calculation(id, inputs)
      let expected = path == .branch ? branchFeet : 5
      #expect(result.equivalentLengthFeet == expected)
      #expect(result.inputs == inputs)
      #expect(
        result.components == [
          .init(ruleKey: "\(id)/\(path.rawValue)", equivalentLengthFeet: expected)
        ])
      let snapshot = try JSONEncoder().encode(result)
      #expect(try JSONDecoder().decode(Fitting.Calculation.self, from: snapshot) == result)
    }
  }

  @Test func junctionPathMustBeExplicitAndEligible() async throws {
    let missing = try await client.evaluate(
      .init(pathType: .supply, fittingID: "9A", inputs: .junction(path: nil)))
    #expect(missing == .unresolved([.init(.missingInput, field: .junctionPath)]))
    let fixed = try await client.evaluate(
      .init(pathType: .supply, fittingID: "9A", inputs: .fixed))
    #expect(fixed == .unresolved([.init(.incompatibleInputs)]))
    let wrongPath = try await client.evaluate(
      .init(pathType: .return, fittingID: "9A", inputs: .junction(path: .branch)))
    #expect(wrongPath == .unresolved([.init(.ineligiblePathType)]))
    let wrongReturn = try await client.evaluate(
      .init(pathType: .supply, fittingID: "10A", inputs: .fixed))
    #expect(wrongReturn == .unresolved([.init(.ineligiblePathType)]))
    let fixedJunction = try await client.evaluate(
      .init(pathType: .supply, fittingID: "9K", inputs: .junction(path: .branch)))
    #expect(fixedJunction == .unresolved([.init(.incompatibleInputs)]))
  }

  @Test func coverageAndPresentationRequirements() async throws {
    let supply = try await client.groups(.supply)
    #expect(supply.first { $0.id == .supplyJunctions }?.availableFittingCount == 18)
    let returns = try await client.groups(.return)
    #expect(returns.first { $0.id == .returnBranches }?.availableFittingCount == 16)
    #expect(returns.first { $0.id == .returnJunctions }?.availableFittingCount == 7)
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .supplyJunctions))
    let junction = try #require(definitions.first { $0.id == "9A" })
    #expect(junction.inputRequirement == .junction)
    #expect(junction.defaultInputs == .junction(path: nil))
    #expect(junction.conditions.notes.contains { $0.contains("Group 2") })
    let reference = try await client.resolveReference(.init(code: " 10g ", pathType: .return))
    #expect(
      reference == .recognized(.init(code: "10G", groupID: .returnJunctions, fittingIDs: ["10G"])))
  }

  private func calculation(_ id: String, _ inputs: Fitting.Inputs) async throws
    -> Fitting.Calculation
  {
    let result = try await client.evaluate(
      .init(
        pathType: id.hasPrefix("9") ? .supply : .return,
        fittingID: Fitting.ID(rawValue: id), inputs: inputs))
    guard case .resolved(let calculation) = result else {
      Issue.record("Expected a resolved calculation for \(id), got \(result)")
      throw FixtureError.unresolved
    }
    return calculation
  }

  private enum FixtureError: Error { case unresolved }
}
