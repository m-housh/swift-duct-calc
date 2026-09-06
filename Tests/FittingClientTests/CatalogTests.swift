import Dependencies
import DependenciesTestSupport
import FittingClient
import Foundation
import ManualDCore
import Testing

@Suite(.dependencies { $0.fittingClient = FittingClient.liveValue })
struct FittingCatalogTests {
  @Dependency(\.fittingClient) var client

  @Test func eligibleGroupsAndPartialCoverage() async throws {
    let supply = try await client.groups(.supply)
    let returns = try await client.groups(.return)
    #expect(supply.map { $0.id.rawValue } == [1, 2, 3, 4, 8, 9, 11, 12])
    #expect(returns.map { $0.id.rawValue } == [5, 6, 7, 8, 10, 11, 12])
    #expect(supply.first?.representativeFittingID == "1F")
    #expect(supply.first?.availableFittingCount == 1)
    #expect(supply.first { $0.id == .flexJunctions }?.availableFittingCount == 0)
    #expect(supply.first { $0.id == .flexJunctions }?.representativeFittingID == nil)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Fitting.Group.ID.self, from: Data("13".utf8))
    }
    let ineligible = try await client.fittings(.init(pathType: .return, groupID: .supplyBoots))
    #expect(ineligible.isEmpty)
  }

  @Test func definitionsRetainSourceIdentityAndRequirements() async throws {
    let supply = try await client.fittings(.init(pathType: .supply, groupID: .supplyEquipment))
    let ratio = try #require(supply.first)
    #expect(ratio.inputRequirement == .heightWidth(exactRatios: [0.5, 1]))
    #expect(ratio.defaultInputs == .heightWidth(heightInches: nil, widthInches: nil))
    #expect(ratio.conditions.notes.contains { $0.contains("10-inch") })
    let returns = try await client.fittings(.init(pathType: .return, groupID: .returnEquipment))
    #expect(returns.map(\.id) == ["5A-rectangular", "5A-round"])
    #expect(returns.map(\.sourceCode) == ["5A", "5B"])
    #expect(returns.allSatisfy { $0.familyID == "5A" })
  }

  @Test func referenceResolutionDoesNotInferLengthOrVariant() async throws {
    let match = try await client.resolveReference(.init(code: " 5b\n", pathType: .return))
    #expect(
      match == .recognized(.init(code: "5B", groupID: .returnEquipment, fittingIDs: ["5A-round"])))
    let wrongPath = try await client.resolveReference(.init(code: "5B", pathType: .supply))
    #expect(
      wrongPath
        == .ineligible(.init(code: "5B", groupID: .returnEquipment, fittingIDs: ["5A-round"])))
    for code in ["5A-round", "11A", "", "../../1F", "4AG"] {
      // 4AG exists in the PDF but is outside this deliberately small first catalog.
      let result = try await client.resolveReference(.init(code: code, pathType: .supply))
      #expect(result == .unknown)
    }
  }

  @Test func artworkWorksBeforeCalculationAndNeverSubstitutes() async throws {
    let image = try await client.artwork(.init(fittingID: "1F"))
    guard case .available(let asset) = image else {
      Issue.record("Missing 1F artwork")
      return
    }
    #expect(asset.publicPath == "/images/fittings/1F.svg")
    #expect(asset.versionedPath == "\(asset.publicPath)?v=\(asset.revision)")
    #expect(asset.revision.count == 64)
    let incomplete = try await client.evaluate(
      .init(
        pathType: .supply, fittingID: "1F",
        inputs: .heightWidth(heightInches: nil, widthInches: nil)))
    guard case .unresolved = incomplete else {
      Issue.record("Missing dimensions should stay unresolved")
      return
    }
    let wrongShape = try await client.artwork(.init(fittingID: "5A-round", shape: .rectangular))
    #expect(wrongShape == .unavailable(.unsupportedShape))
    let wrongView = try await client.artwork(.init(fittingID: "1F", view: .assembly))
    #expect(wrongView == .unavailable(.unsupportedView))
    let unknown = try await client.artwork(.init(fittingID: "../../files/ManD.Groups.pdf"))
    #expect(unknown == .unavailable(.unknownFitting))
  }

  @Test func packagedReferencesPointToExistingApprovedAssets() async throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    var checked: Set<Fitting.ID> = []
    for pathType in [Fitting.PathType.supply, .return] {
      for group in try await client.groups(pathType) {
        let definitions = try await client.fittings(.init(pathType: pathType, groupID: group.id))
        for definition in definitions where checked.insert(definition.id).inserted {
          let result = try await client.artwork(.init(fittingID: definition.id))
          guard case .available(let artwork) = result else {
            Issue.record("Missing artwork for \(definition.id)")
            continue
          }
          let svg = root.appendingPathComponent("Public" + artwork.publicPath)
          #expect(try String(contentsOf: svg, encoding: .utf8).contains("<svg"))
        }
      }
    }
    #expect(checked.count == 5)
  }

  @Test func dependencyCanBeReplacedWithoutLoadingCatalogOrProjects() async throws {
    try await withDependencies {
      $0.fittingClient.groups = { _ in
        [
          .init(
            id: .supplyBoots, title: "Test group", representativeFittingID: nil,
            availableFittingCount: 0)
        ]
      }
    } operation: {
      @Dependency(\.fittingClient) var overridden
      let groups = try await overridden.groups(.supply)
      #expect(groups.map(\.title) == ["Test group"])
    }
  }
}
