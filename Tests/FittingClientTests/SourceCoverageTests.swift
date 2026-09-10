import FittingClient
import Foundation
import ManualDCore
import Testing

/// PDF-derived expectations; these values are not loaded from the runtime catalog.
/// See docs/internals/fitting-rules.md for source interpretation decisions.
struct FittingSourceCoverageTests {
  let client: FittingClient

  init() async throws {
    client = try await loadBundledFittingClient()
  }

  @Test(arguments: [
    ("1A", 35.0),
    ("1B", 10.0),
    ("1C", 35.0),
    ("1D", 10.0),
    ("1E", 10.0),
    ("1I", 20.0),
    ("1K", 85.0),
    ("1N", 15.0),
    ("1P", 20.0),
    ("1Q", 50.0),
    ("1R", 120.0),
    ("1S-0-vanes", 60.0),
    ("1S-1-vane", 40.0),
    ("1S-2-vanes", 30.0),
    ("1T", 60.0),
    ("4A", 30.0),
    ("4B", 35.0),
    ("4C", 60.0),
    ("4D", 55.0),
    ("4E", 70.0),
    ("4F", 45.0),
    ("4G", 80.0),
    ("4H", 50.0),
    ("4I", 10.0),
    ("4J", 30.0),
    ("4K", 30.0),
    ("4L", 80.0),
    ("4M", 20.0),
    ("4N", 45.0),
    ("4O", 20.0),
    ("4P", 10.0),
    ("4Q", 50.0),
    ("4R", 20.0),
    ("4S", 20.0),
    ("4T", 20.0),
    ("4U", 20.0),
    ("4V", 60.0),
    ("4W", 35.0),
    ("4X", 35.0),
    ("4Y", 35.0),
    ("4Z", 60.0),
    ("4AA", 35.0),
    ("4AB", 90.0),
    ("4AC", 100.0),
    ("4AD", 60.0),
    ("4AE", 55.0),
    ("4AF", 50.0),
    ("4AG", 60.0),
    ("4AH", 60.0),
    ("4AI", 20.0),
    ("4AJ", 25.0),
    ("4AK", 55.0),
    ("4AL", 70.0),
    ("4AM", 70.0),
    ("4AN", 70.0),
    ("4AO", 40.0),
    ("4AP", 40.0),
    ("4AQ", 10.0),
    ("4AR", 70.0),
    ("5A-rectangular", 40.0),
    ("5A-round", 40.0),
    ("5C-rectangular", 40.0),
    ("5C-round", 40.0),
    ("5K-rectangular", 10.0),
    ("5L-rectangular", 75.0),
    ("5M-rectangular", 10.0),
    ("5N-rectangular", 55.0),
    ("5O-rectangular", 35.0),
  ])
  func fixedSourceValues(id: String, expected: Double) async throws {
    let result = try await calculation(id, .fixed)
    #expect(result.equivalentLengthFeet == expected)
  }

  @Test(arguments: [
    ("2A", [35, 45, 55, 65, 70, 80]),
    ("2B", [20, 30, 35, 40, 45, 50]),
    ("2C", [65, 65, 65, 65, 70, 80]),
    ("2D", [40, 50, 60, 65, 75, 85]),
    ("2E", [25, 30, 35, 40, 45, 50]),
    ("2F", [20, 20, 20, 20, 25, 25]),
    ("2G", [65, 65, 65, 70, 80, 90]),
    ("2H", [70, 70, 70, 75, 85, 95]),
    ("2I", [65, 75, 85, 95, 100, 110]),
    ("2J", [50, 60, 65, 70, 75, 80]),
    ("2K", [50, 60, 65, 70, 75, 80]),
    ("2L", [70, 80, 90, 95, 105, 115]),
    ("2M", [70, 80, 90, 95, 105, 115]),
    ("2N", [35, 35, 40, 40, 40, 40]),
    ("2O", [55, 65, 75, 85, 90, 100]),
    ("2P", [50, 55, 60, 65, 70, 75]),
    ("2Q", [10, 10, 15, 20, 20, 25]),
  ])
  func downstreamSourceValues(id: String, expected: [Double]) async throws {
    for (count, feet) in expected.enumerated() {
      let result = try await calculation(id, .downstreamBranches(count: count))
      #expect(result.equivalentLengthFeet == feet)
    }
    for count in [6, Int.max] {
      let result = try await calculation(id, .downstreamBranches(count: count))
      #expect(result.equivalentLengthFeet == expected.last)
      #expect(result.inputs == .downstreamBranches(count: count))
    }
  }

  @Test(arguments: [
    ("1F", 0.5, 120.0),
    ("1F", 1.0, 85.0),
    ("1G", 0.5, 35.0),
    ("1G", 1.0, 25.0),
    ("1H", 0.5, 120.0),
    ("1H", 1.0, 85.0),
    ("1O", 0.5, 120.0),
    ("1O", 1.0, 85.0),
    ("5H-rectangular", 1.0, 45.0),
    ("5H-rectangular", 2.0, 30.0),
    ("5I-rectangular", 1.0, 45.0),
    ("5I-rectangular", 2.0, 30.0),
  ])
  func heightWidthSourceValues(id: String, ratio: Double, expected: Double) async throws {
    let result = try await calculation(id, .heightWidth(heightInches: ratio * 20, widthInches: 20))
    #expect(result.equivalentLengthFeet == expected)
  }

  @Test(arguments: [
    ("1L", 0.25, 40.0),
    ("1L", 0.5, 20.0),
    ("1L", 1.0, 10.0),
    ("1M-1-vane", 0.05, 30.0),
    ("1M-1-vane", 0.25, 20.0),
    ("1M-1-vane", 0.5, 10.0),
    ("1M-2-vanes", 0.05, 20.0),
    ("1M-2-vanes", 0.25, 10.0),
    ("1M-2-vanes", 0.5, 10.0),
    ("5J-rectangular", 0.25, 20.0),
    ("5J-rectangular", 0.5, 15.0),
    ("5J-rectangular", 1.0, 10.0),
  ])
  func radiusWidthSourceValues(id: String, ratio: Double, expected: Double) async throws {
    let inputs = Fitting.Inputs.radiusWidth(radiusInches: ratio * 20, widthInches: 20)
    let result = try await calculation(id, inputs)
    #expect(result.equivalentLengthFeet == expected)
    #expect(result.inputs == inputs)
  }

  @Test(arguments: [
    ("5E-rectangular", 10.0, 35.0), ("5E-round", 10.0, 35.0),
    ("5F-rectangular", 45.0, 70.0), ("5F-round", 45.0, 70.0),
  ])
  func plenumReturnSourceValues(id: String, single: Double, multiple: Double) async throws {
    for count in [1, 2, 3, Int.max] {
      let result = try await calculation(id, .plenumReturns(count: count))
      #expect(result.equivalentLengthFeet == (count == 1 ? single : multiple))
      #expect(result.inputs == .plenumReturns(count: count))
    }
  }

  @Test func groupCoverageAndVariantIdentity() async throws {
    let supply = try await client.groups(.supply)
    #expect(
      supply.filter { [1, 2, 4].contains($0.id.rawValue) }.map(\.availableFittingCount) == [
        22, 17, 44,
      ])
    let returns = try await client.groups(.return)
    #expect(returns.first?.availableFittingCount == 16)
    let vanes = try await client.resolveReference(.init(code: "1M", pathType: .supply))
    #expect(
      vanes
        == .recognized(
          .init(
            code: "1M", groupID: .supplyEquipment,
            fittingIDs: ["1M-1-vane", "1M-2-vanes"])))
    let shapes = try await client.resolveReference(.init(code: "5E", pathType: .return))
    #expect(
      shapes
        == .recognized(
          .init(
            code: "5E", groupID: .returnEquipment,
            fittingIDs: ["5E-rectangular", "5E-round"])))
    let roundSide = try await client.resolveReference(.init(code: "5G", pathType: .return))
    #expect(
      roundSide
        == .recognized(
          .init(
            code: "5G", groupID: .returnEquipment,
            fittingIDs: ["5F-round"])))
    let definitions = try await client.fittings(.init(pathType: .return, groupID: .returnEquipment))
    let radius = try #require(definitions.first { $0.id == "5J-rectangular" })
    #expect(radius.inputRequirement == .radiusWidth(exactRatios: [0.25, 0.5, 1]))
    #expect(radius.defaultInputs == .radiusWidth(radiusInches: nil, widthInches: nil))
    let plenum = try #require(definitions.first { $0.id == "5E-round" })
    #expect(plenum.inputRequirement == .plenumReturns(finalBucketMinimum: 2))
    #expect(plenum.defaultInputs == .plenumReturns(count: nil))
  }

  @Test func newInputsValidateTheirOwnFieldsAndDoNotInterpolate() async throws {
    for (inputs, issues) in [
      (
        Fitting.Inputs.radiusWidth(radiusInches: nil, widthInches: nil),
        [
          Fitting.Issue(.missingInput, field: .radiusInches),
          .init(.missingInput, field: .widthInches),
        ]
      ),
      (
        .radiusWidth(radiusInches: 0, widthInches: -1),
        [
          .init(.nonpositiveDimension, field: .radiusInches),
          .init(.nonpositiveDimension, field: .widthInches),
        ]
      ),
      (
        .radiusWidth(radiusInches: .nan, widthInches: .infinity),
        [.init(.nonfiniteInput, field: .radiusInches), .init(.nonfiniteInput, field: .widthInches)]
      ),
      (.radiusWidth(radiusInches: 0.3, widthInches: 1), [.init(.unsupportedRatio)]),
      (.radiusWidth(radiusInches: 2, widthInches: 1), [.init(.unsupportedRatio)]),
      (.heightWidth(heightInches: 0.5, widthInches: 1), [.init(.incompatibleInputs)]),
    ] {
      let result = try await client.evaluate(
        .init(pathType: .supply, fittingID: "1L", inputs: inputs))
      #expect(result == .unresolved(issues))
    }
    for count in [nil, 0, -1] as [Int?] {
      let result = try await client.evaluate(
        .init(
          pathType: .return,
          fittingID: "5E-round", inputs: .plenumReturns(count: count)))
      #expect(
        result
          == .unresolved([
            .init(
              count == nil ? .missingInput : .nonpositiveReturnCount,
              field: .plenumReturns)
          ]))
    }
    let wrongCountKind = try await client.evaluate(
      .init(
        pathType: .return,
        fittingID: "5E-round", inputs: .downstreamBranches(count: 1)))
    #expect(wrongCountKind == .unresolved([.init(.incompatibleInputs)]))
  }

  @Test func newInputSnapshotsRoundTrip() async throws {
    for (id, inputs) in [
      ("1M-1-vane", Fitting.Inputs.radiusWidth(radiusInches: 1, widthInches: 20)),
      ("5E-round", .plenumReturns(count: 3)),
    ] {
      let result = try await calculation(id, inputs)
      let encoded = try JSONEncoder().encode(result)
      #expect(try JSONDecoder().decode(Fitting.Calculation.self, from: encoded) == result)
    }
  }

  private func calculation(_ id: String, _ inputs: Fitting.Inputs) async throws
    -> Fitting.Calculation
  {
    let result = try await client.evaluate(
      .init(
        pathType: id.hasPrefix("5") ? .return : .supply,
        fittingID: Fitting.ID(rawValue: id), inputs: inputs))
    guard case .resolved(let calculation) = result else {
      Issue.record("Expected a resolved calculation for \(id), got \(result)")
      throw FixtureError.unresolved
    }
    return calculation
  }

  private enum FixtureError: Error { case unresolved }
}
