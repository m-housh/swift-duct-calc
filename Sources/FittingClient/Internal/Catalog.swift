import Foundation
import ManualDCore

struct Catalog: Sendable {
  let revision: String
  let groupRecords: [GroupRecord]
  let records: [Record]
  let byID: [Fitting.ID: Record]

  init(data: Data) throws {
    let document: Document
    do {
      document = try JSONDecoder().decode(Document.self, from: data)
    } catch {
      throw FittingClientError.invalidCatalog("Cannot decode catalog: \(error)")
    }
    // Keep only the structural guarantees required by lookup and table indexing.
    guard document.schemaVersion == 1 else {
      throw FittingClientError.invalidCatalog("Unsupported schema version")
    }
    guard Set(document.groups.map(\.id)) == Set(Fitting.Group.ID.allCases),
      document.groups.count == Fitting.Group.ID.allCases.count
    else {
      throw FittingClientError.invalidCatalog("Groups must occur once each")
    }
    guard Set(document.fittings.map(\.id)).count == document.fittings.count else {
      throw FittingClientError.invalidCatalog("Duplicate fitting ID")
    }
    guard document.fittings.allSatisfy({ !$0.rule.rows.isEmpty }) else {
      throw FittingClientError.invalidCatalog("Rule has no source rows")
    }
    revision = document.revision
    groupRecords = document.groups
    records = document.fittings
    byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
  }

  func groups(for pathType: Fitting.PathType) -> [Fitting.Group] {
    groupRecords.filter { $0.pathTypes.contains(pathType) }.map { group in
      let fittings = records.filter { $0.groupID == group.id }
      return .init(
        id: group.id, title: group.title, representativeFittingID: fittings.first?.id,
        availableFittingCount: fittings.count
      )
    }
  }

  func pathTypes(for record: Record) -> [Fitting.PathType] {
    groupRecords.first { $0.id == record.groupID }!.pathTypes
  }

  func fittings(_ request: Fitting.BrowseRequest) -> [Fitting.Definition] {
    records.filter {
      $0.groupID == request.groupID && pathTypes(for: $0).contains(request.pathType)
    }.map { record in
      .init(
        id: record.id, groupID: record.groupID, familyID: record.familyID,
        sourceCode: record.sourceCode, name: record.name, shape: record.shape,
        pathTypes: pathTypes(for: record), inputRequirement: record.rule.requirement,
        defaultInputs: record.rule.defaultInputs, conditions: record.conditions,
        availableViews: record.artworks.map(\.view)
      )
    }
  }

  func artwork(_ request: Fitting.ArtworkRequest) -> Fitting.ArtworkResolution {
    guard let record = byID[request.fittingID] else { return .unavailable(.unknownFitting) }
    guard request.shape == nil || request.shape == record.shape else {
      return .unavailable(.unsupportedShape)
    }
    guard let artwork = record.artworks.first(where: { $0.view == request.view }) else {
      return .unavailable(.unsupportedView)
    }
    return .available(artwork)
  }

  func resolveReference(_ request: Fitting.ReferenceRequest) -> Fitting.ReferenceMatch {
    let code = request.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let candidates = records.filter { $0.sourceCode?.rawValue == code }
    guard let first = candidates.first, let sourceCode = first.sourceCode else { return .unknown }
    let reference = Fitting.Reference(
      code: sourceCode, groupID: first.groupID, fittingIDs: candidates.map(\.id)
    )
    return pathTypes(for: first).contains(request.pathType)
      ? .recognized(reference) : .ineligible(reference)
  }

  struct GroupRecord: Decodable, Sendable {
    let id: Fitting.Group.ID
    let title: String
    let pathTypes: [Fitting.PathType]
  }

  struct Record: Decodable, Sendable {
    let id: Fitting.ID
    let familyID: Fitting.ID
    let groupID: Fitting.Group.ID
    let sourceCode: Fitting.SourceCode?
    let name: String
    let shape: Fitting.Shape
    let conditions: Fitting.Conditions
    let artwork: Fitting.Artwork
    let alternateArtwork: [Fitting.Artwork]?
    let ruleRevision: String
    let rule: Rule

    var artworks: [Fitting.Artwork] { [artwork] + (alternateArtwork ?? []) }
  }

  struct Rule: Decodable, Sendable {
    let kind: Kind
    let rows: [Row]
    let firstRowIncludesLowerRatios: Bool?
    let mergingFlowFeet: Double?
    let angleMultipliers: [AngleMultiplier]?

    var requirement: Fitting.InputRequirement {
      switch kind {
      case .fixed: .fixed
      case .ovalElbow:
        .ovalElbow(
          pieceCounts: Fitting.OvalElbowPieceCount.allCases.filter { count in
            rows.contains { $0.parameter == Double(count.rawValue) }
          })
      case .rectangularElbow:
        .rectangularElbow(
          radiusRatios: Fitting.RectangularElbowRadiusRatio.allCases.filter { ratio in
            rows.contains { $0.parameter == ratio.rawValue }
          },
          bendCategories: Fitting.ElbowBendCategory.allCases.filter { category in
            rows.contains { $0.bendCategory == category }
          },
          angles: (angleMultipliers ?? []).map(\.angle))
      case .roundElbow:
        .roundElbow(
          radiusRatios: rows.compactMap { Fitting.RoundElbowRadiusRatio(rawValue: $0.parameter) },
          angles: (angleMultipliers ?? []).map(\.angle))
      case .heightWidth: .heightWidth(exactRatios: rows.map(\.parameter))
      case .radiusWidth: .radiusWidth(exactRatios: rows.map(\.parameter))
      case .downstreamBranches: .downstreamBranches(finalBucketMinimum: rows.count - 1)
      case .plenumReturns: .plenumReturns(finalBucketMinimum: rows.count)
      case .junction: .junction
      case .pannedReturn:
        .pannedReturn(
          airflowRows: rows.map(\.parameter), supportsMergingFlow: mergingFlowFeet != nil)
      case .returnJunction:
        .returnJunction(
          ratios: rows.map(\.parameter),
          firstRowIncludesLowerRatios: firstRowIncludesLowerRatios == true)
      }
    }

    var defaultInputs: Fitting.Inputs {
      switch kind {
      case .fixed: .fixed
      case .ovalElbow: .ovalElbow(pieceCount: nil)
      case .roundElbow: .roundElbow(radiusRatio: nil, angle: .degrees90)
      case .rectangularElbow:
        .rectangularElbow(radiusRatio: .mitered, bendCategory: nil, angle: .degrees90)
      case .heightWidth: .heightWidth(heightInches: nil, widthInches: nil)
      case .radiusWidth: .radiusWidth(radiusInches: nil, widthInches: nil)
      case .downstreamBranches: .downstreamBranches(count: nil)
      case .plenumReturns: .plenumReturns(count: nil)
      case .junction: .junction(path: nil)
      case .pannedReturn: .pannedReturn(airflowCFM: nil, mergingFlow: false)
      case .returnJunction: .returnJunction(branchCFM: nil, totalCFM: nil)
      }
    }

    enum Kind: String, Decodable, Sendable {
      case fixed, heightWidth, radiusWidth, downstreamBranches, plenumReturns, junction,
        returnJunction, pannedReturn, roundElbow, rectangularElbow, ovalElbow
    }

    struct AngleMultiplier: Decodable, Sendable {
      let angle: Fitting.ElbowAngle
      let multiplier: Double
    }

    struct Row: Decodable, Sendable {
      let key: String
      let parameter: Double
      let feet: Double
      let path: Fitting.JunctionPath?
      let bendCategory: Fitting.ElbowBendCategory?
      /// The group 6 trunk column; `feet` holds that row's branch value.
      let trunkFeet: Double?
    }
  }

  struct Document: Decodable {
    let schemaVersion: Int
    let revision: String
    let groups: [GroupRecord]
    let fittings: [Record]
  }
}
