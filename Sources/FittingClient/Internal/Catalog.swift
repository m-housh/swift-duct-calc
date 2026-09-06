import Foundation
import ManualDCore

struct Catalog: Sendable {
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
    let ruleRevision: String
    let rule: Rule
  }

  struct Rule: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable { case fixed, heightWidth, downstreamBranches }
    struct Row: Decodable, Sendable {
      let key: String
      let parameter: Double
      let feet: Double
    }
    let kind: Kind
    let rows: [Row]

    var requirement: Fitting.InputRequirement {
      switch kind {
      case .fixed: .fixed
      case .heightWidth: .heightWidth(exactRatios: rows.map(\.parameter))
      case .downstreamBranches: .downstreamBranches(finalBucketMinimum: rows.count - 1)
      }
    }

    var defaultInputs: Fitting.Inputs {
      switch kind {
      case .fixed: .fixed
      case .heightWidth: .heightWidth(heightInches: nil, widthInches: nil)
      case .downstreamBranches: .downstreamBranches(count: nil)
      }
    }
  }

  private struct Document: Decodable {
    let schemaVersion: Int
    let revision: String
    let groups: [GroupRecord]
    let fittings: [Record]
  }

  static let bundled: Result<Catalog, Error> = Result {
    guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
      throw FittingClientError.missingCatalog
    }
    return try Catalog(data: Data(contentsOf: url))
  }

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
    func require(_ condition: Bool, _ message: String) throws {
      guard condition else { throw FittingClientError.invalidCatalog(message) }
    }
    try require(document.schemaVersion == 1, "Unsupported schema version")
    try require(!document.revision.isEmpty, "Missing catalog revision")
    try require(
      document.groups.map(\.id) == Fitting.Group.ID.allCases,
      "Groups must occur once each in canonical order"
    )
    for group in document.groups {
      try require(!group.title.isEmpty && !group.pathTypes.isEmpty, "Missing group metadata")
      try require(
        Set(group.pathTypes.map(\.rawValue)).count == group.pathTypes.count, "Duplicate path type")
    }
    try require(
      Set(document.fittings.map(\.id)).count == document.fittings.count, "Duplicate fitting ID")
    for record in document.fittings {
      try require(
        !record.id.rawValue.isEmpty && !record.familyID.rawValue.isEmpty, "Missing identity")
      try require(!record.name.isEmpty && !record.ruleRevision.isEmpty, "Missing fitting metadata")
      if let code = record.sourceCode {
        try require(
          code.rawValue.range(of: #"^(?:[1-9]|1[0-2])[A-Z]+$"#, options: .regularExpression) != nil,
          "Invalid source code"
        )
        let sourceGroup = Int(code.rawValue.prefix(while: { $0.isNumber }))
        try require(sourceGroup == record.groupID.rawValue, "Source group mismatch")
      }
      try require(
        record.artwork.publicPath.hasPrefix("/images/fittings/")
          && !record.artwork.publicPath.contains("..")
          && record.artwork.publicPath.range(
            of: #"^/[A-Za-z0-9/_-]+\.svg$"#, options: .regularExpression) != nil,
        "Artwork must be a catalog-owned SVG path"
      )
      try require(
        record.artwork.revision.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil,
        "Invalid artwork revision hash")
      try require(
        record.artwork.mediaType == "image/svg+xml" && !record.artwork.altText.isEmpty,
        "Invalid artwork metadata")
      try require(record.conditions.referenceVelocityFPM > 0, "Invalid reference velocity")
      try require(
        record.conditions.frictionRateIWCPer100Feet.isFinite
          && record.conditions.frictionRateIWCPer100Feet > 0, "Invalid friction rate")
      let rows = record.rule.rows
      try require(!rows.isEmpty, "Rule has no source rows")
      try require(
        Set(rows.map(\.key)).count == rows.count && rows.allSatisfy { !$0.key.isEmpty },
        "Invalid source row keys")
      try require(
        rows.allSatisfy { $0.parameter.isFinite && $0.feet.isFinite && $0.feet > 0 },
        "Invalid source values")
      switch record.rule.kind {
      case .fixed:
        try require(rows.count == 1, "Fixed rule must have one row")
      case .heightWidth:
        try require(rows.allSatisfy { $0.parameter > 0 }, "Ratios must be positive")
        try require(Set(rows.map(\.parameter)).count == rows.count, "Duplicate ratio")
      case .downstreamBranches:
        try require(
          rows.enumerated().allSatisfy { Double($0.offset) == $0.element.parameter },
          "Branch buckets must be contiguous from zero")
      }
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
        defaultInputs: record.rule.defaultInputs, conditions: record.conditions
      )
    }
  }

  func artwork(_ request: Fitting.ArtworkRequest) -> Fitting.ArtworkResolution {
    guard let record = byID[request.fittingID] else { return .unavailable(.unknownFitting) }
    guard request.shape == nil || request.shape == record.shape else {
      return .unavailable(.unsupportedShape)
    }
    guard request.view == record.artwork.view else { return .unavailable(.unsupportedView) }
    return .available(record.artwork)
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
}
