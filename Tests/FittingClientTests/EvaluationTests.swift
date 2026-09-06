import Dependencies
import DependenciesTestSupport
import FittingClient
import Foundation
import ManualDCore
import Testing

@Suite(.dependencies { $0.fittingClient = FittingClient.liveValue })
struct FittingEvaluationTests {
  @Dependency(\.fittingClient) var client

  @Test func fixedValueAndProvenance() async throws {
    let value = try await calculation("4A", .fixed)
    #expect(value.equivalentLengthFeet == 30)
    #expect(value.inputs == .fixed)
    #expect(value.components == [.init(ruleKey: "4A", equivalentLengthFeet: 30)])
    #expect(value.conditions.referenceVelocityFPM == 900)
    #expect(value.conditions.frictionRateIWCPer100Feet == 0.08)
    #expect(value.catalogRevision == "fitting-catalog-v2")
    #expect(value.ruleRevision == "4A-v1")
    let roundReturn = try await calculation("5A-round", .fixed, type: .return)
    #expect(roundReturn.equivalentLengthFeet == 40)
    #expect(roundReturn.sourceCode == "5B")
  }

  @Test(arguments: [(10.0, 20.0, 120.0), (20.0, 20.0, 85.0), (0.5, 1.0, 120.0)])
  func exactSourceRatios(height: Double, width: Double, expected: Double) async throws {
    let inputs = Fitting.Inputs.heightWidth(heightInches: height, widthInches: width)
    let result = try await calculation("1F", inputs)
    #expect(result.equivalentLengthFeet == expected)
    #expect(result.inputs == inputs)
    #expect(result.conditions.notes.contains { $0.contains("10-inch") })
  }

  @Test(arguments: [
    (0, 35.0), (1, 45.0), (2, 55.0), (3, 65.0), (4, 70.0), (5, 80.0), (6, 80.0), (Int.max, 80.0),
  ])
  func downstreamBuckets(count: Int, expected: Double) async throws {
    let result = try await calculation("2A", .downstreamBranches(count: count))
    #expect(result.equivalentLengthFeet == expected)
    #expect(result.inputs == .downstreamBranches(count: count))
  }

  @Test func invalidAndIncompleteInputsStayUnresolved() async throws {
    let cases: [(Fitting.ID, Fitting.Inputs, [Fitting.Issue])] = [
      (
        "1F", .heightWidth(heightInches: nil, widthInches: nil),
        [.init(.missingInput, field: .heightInches), .init(.missingInput, field: .widthInches)]
      ),
      (
        "1F", .heightWidth(heightInches: 0, widthInches: 20),
        [.init(.nonpositiveDimension, field: .heightInches)]
      ),
      (
        "1F", .heightWidth(heightInches: 10, widthInches: -1),
        [.init(.nonpositiveDimension, field: .widthInches)]
      ),
      (
        "1F", .heightWidth(heightInches: .nan, widthInches: 20),
        [.init(.nonfiniteInput, field: .heightInches)]
      ),
      (
        "1F", .heightWidth(heightInches: 10, widthInches: .infinity),
        [.init(.nonfiniteInput, field: .widthInches)]
      ),
      ("1F", .heightWidth(heightInches: 12, widthInches: 20), [.init(.unsupportedRatio)]),
      ("1F", .heightWidth(heightInches: 10.000000001, widthInches: 20), [.init(.unsupportedRatio)]),
      (
        "1F",
        .heightWidth(heightInches: .greatestFiniteMagnitude, widthInches: .leastNonzeroMagnitude),
        [.init(.unsupportedRatio)]
      ),
      ("2A", .downstreamBranches(count: nil), [.init(.missingInput, field: .downstreamBranches)]),
      (
        "2A", .downstreamBranches(count: -1),
        [.init(.negativeBranchCount, field: .downstreamBranches)]
      ),
      ("1F", .fixed, [.init(.incompatibleInputs)]),
      ("4A", .downstreamBranches(count: 2), [.init(.incompatibleInputs)]),
    ]
    for (id, inputs, issues) in cases {
      let result = try await client.evaluate(
        .init(pathType: .supply, fittingID: id, inputs: inputs))
      #expect(result == .unresolved(issues))
    }
  }

  @Test func directRequestsRecheckEligibility() async throws {
    let ineligible = try await client.evaluate(
      .init(pathType: .return, fittingID: "4A", inputs: .fixed))
    #expect(ineligible == .unresolved([.init(.ineligiblePathType)]))
    let unknown = try await client.evaluate(
      .init(pathType: .supply, fittingID: "3W", inputs: .fixed))
    #expect(unknown == .unresolved([.init(.unknownFitting)]))
  }

  @Test func calculationSnapshotPreservesFractionalValues() async throws {
    let source = try await calculation("4A", .fixed)
    // Contract fixture only: deliberately not a claim that source fitting 4A has this EL.
    let fractional = Fitting.Calculation(
      fittingID: "test-fractional", sourceCode: "4A", equivalentLengthFeet: 7.5,
      inputs: .fixed, components: [.init(ruleKey: "test-only", equivalentLengthFeet: 7.5)],
      conditions: source.conditions, catalogRevision: "test-only", ruleRevision: "test-only"
    )
    let encoded = try JSONEncoder().encode(fractional)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(object["source"] == nil)
    #expect(!String(decoding: encoded, as: UTF8.self).lowercased().contains("pdf"))
    let restored = try JSONDecoder().decode(
      Fitting.Calculation.self, from: JSONEncoder().encode(fractional))
    #expect(restored == fractional)
    #expect(restored.equivalentLengthFeet == 7.5)
  }

  private func calculation(
    _ id: Fitting.ID, _ inputs: Fitting.Inputs, type: Fitting.PathType = .supply
  ) async throws -> Fitting.Calculation {
    let result = try await client.evaluate(.init(pathType: type, fittingID: id, inputs: inputs))
    guard case .resolved(let calculation) = result else {
      throw ExpectedCalculation.unresolved
    }
    return calculation
  }

  private enum ExpectedCalculation: Error { case unresolved }
}
