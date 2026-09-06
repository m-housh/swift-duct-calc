import Foundation
import ManualDCore

@testable import FittingClient

/// Checks authored catalog content during tests, before it is shipped.
struct CatalogValidator {
  static func validate(_ document: Catalog.Document) throws {
    func require(_ condition: Bool, _ message: String) throws {
      guard condition else { throw ValidationError(message: message) }
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
      case .heightWidth, .radiusWidth:
        try require(rows.allSatisfy { $0.parameter > 0 }, "Ratios must be positive")
        try require(Set(rows.map(\.parameter)).count == rows.count, "Duplicate ratio")
      case .downstreamBranches:
        try require(
          rows.enumerated().allSatisfy { Double($0.offset) == $0.element.parameter },
          "Branch buckets must be contiguous from zero")
      case .plenumReturns:
        try require(
          rows.enumerated().allSatisfy { Double($0.offset + 1) == $0.element.parameter },
          "Return buckets must be contiguous from one")
      }
    }
  }

  struct ValidationError: Error, Equatable {
    let message: String
  }
}
