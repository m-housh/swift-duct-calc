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
        Set(record.artworks.map(\.view)).count == record.artworks.count,
        "Duplicate artwork view")
      for artwork in record.artworks {
        try require(
          artwork.publicPath.hasPrefix("/images/fittings/")
            && !artwork.publicPath.contains("..")
            && artwork.publicPath.range(
              of: #"^/[A-Za-z0-9/_-]+\.svg$"#, options: .regularExpression) != nil,
          "Artwork must be a catalog-owned SVG path"
        )
        try require(
          artwork.revision.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil,
          "Invalid artwork revision hash")
        try require(
          artwork.mediaType == "image/svg+xml" && !artwork.altText.isEmpty,
          "Invalid artwork metadata")
      }
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
      if record.rule.kind != .junction {
        try require(rows.allSatisfy { $0.path == nil }, "Unexpected junction path")
      }
      if record.rule.kind != .returnJunction {
        try require(
          record.rule.firstRowIncludesLowerRatios == nil && rows.allSatisfy { $0.trunkFeet == nil },
          "Unexpected return junction metadata")
      }
      if let feet = record.rule.mergingFlowFeet {
        try require(
          record.rule.kind == .pannedReturn && record.sourceCode == "7C" && feet == 40,
          "Unexpected merging-flow adjustment")
      }
      if record.rule.kind != .roundElbow && record.rule.kind != .rectangularElbow {
        try require(record.rule.angleMultipliers == nil, "Unexpected elbow angle metadata")
      }
      if record.rule.kind != .rectangularElbow {
        try require(rows.allSatisfy { $0.bendCategory == nil }, "Unexpected bend category")
      }
      switch record.rule.kind {
      case .rectangularElbow:
        let ratios = Fitting.RectangularElbowRadiusRatio.allCases
        let categories = Fitting.ElbowBendCategory.allCases
        try require(
          record.groupID == .elbows && record.shape == .rectangular
            && ["8B", "8C"].contains(record.sourceCode?.rawValue)
            && rows.count == ratios.count * categories.count
            && rows.enumerated().allSatisfy { index, row in
              row.parameter == ratios[index / categories.count].rawValue
                && row.bendCategory == categories[index % categories.count]
            },
          "Rectangular elbow must have each R/W and bend category pair in order")
        let factors = record.rule.angleMultipliers ?? []
        try require(
          factors.map(\.angle) == [.degrees30, .degrees45, .degrees60, .degrees90]
            && factors.map(\.multiplier) == [0.45, 0.60, 0.78, 1],
          "Invalid rectangular elbow angle multipliers")
      case .roundElbow:
        try require(
          record.groupID == .elbows && record.sourceCode == "8A" && record.shape == .round
            && rows.map(\.parameter) == Fitting.RoundElbowRadiusRatio.allCases.map(\.rawValue),
          "Round elbow must have each published R/D category in order")
        let factors = record.rule.angleMultipliers ?? []
        let expectedAngles: [Fitting.ElbowAngle] =
          record.id == "8A-smooth"
          ? Fitting.ElbowAngle.allCases : [.degrees90]
        try require(
          factors.map(\.angle) == expectedAngles
            && factors.allSatisfy { $0.multiplier.isFinite && $0.multiplier > 0 }
            && factors.first { $0.angle == .degrees90 }?.multiplier == 1,
          "Invalid round elbow angle multipliers")
      case .pannedReturn:
        try require(
          record.groupID == .pannedReturns
            && rows.allSatisfy { $0.parameter > 0 && $0.parameter.rounded() == $0.parameter }
            && zip(rows, rows.dropFirst()).allSatisfy { $0.parameter < $1.parameter },
          "Panned return airflow rows must be positive whole CFM in increasing order")
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
      case .returnJunction:
        try require(
          record.rule.firstRowIncludesLowerRatios != nil, "Missing first-row range policy")
        try require(
          rows.allSatisfy { $0.parameter > 0 && $0.parameter <= 1 }
            && zip(rows, rows.dropFirst()).allSatisfy { $0.parameter < $1.parameter }
            && rows.last?.parameter == 1,
          "Return junction ratios must increase to one")
        try require(
          rows.allSatisfy { row in
            if row.parameter == 1 { return row.trunkFeet == nil }
            guard let feet = row.trunkFeet else { return false }
            return feet.isFinite && feet > 0
          },
          "Return junction trunk values must be positive, with NA only at ratio one")
      case .junction:
        try require(
          rows.count == Fitting.JunctionPath.allCases.count
            && rows.compactMap(\.path) == Fitting.JunctionPath.allCases,
          "Junction must have one row for each path in canonical order")
      }
    }
  }

  struct ValidationError: Error, Equatable {
    let message: String
  }
}
