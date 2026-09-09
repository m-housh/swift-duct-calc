import Foundation
import Testing

@testable import FittingClient

struct FittingResourceValidationTests {
  private func document() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(
      contentsOf: root.appendingPathComponent("Sources/FittingClient/Resources/catalog.json"))
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  @Test(arguments: ["duplicateID", "missingGroup", "emptyRows"])
  func runtimeLoadingRejectsUnsafeStructure(fault: String) throws {
    var doc = try document()
    switch fault {
    case "duplicateID":
      var records = try #require(doc["fittings"] as? [[String: Any]])
      records.append(records[0])
      doc["fittings"] = records
    case "missingGroup":
      var groups = try #require(doc["groups"] as? [[String: Any]])
      groups.removeFirst()
      doc["groups"] = groups
    default:
      var records = try #require(doc["fittings"] as? [[String: Any]])
      var rule = try #require(records[0]["rule"] as? [String: Any])
      rule["rows"] = [] as [Any]
      records[0]["rule"] = rule
      doc["fittings"] = records
    }
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(throws: FittingClientError.self) {
      try Catalog(data: data)
    }
  }

  @Test func checkedInCatalogPassesValidation() throws {
    let data = try JSONSerialization.data(withJSONObject: document())
    try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
  }

  @Test func duplicateIDsAreRejected() throws {
    var doc = try document()
    var records = try #require(doc["fittings"] as? [[String: Any]])
    records.append(records[0])
    doc["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(throws: CatalogValidator.ValidationError(message: "Duplicate fitting ID")) {
      try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
    }
  }

  @Test func malformedTablesAreRejectedByValidator() throws {
    var doc = try document()
    var records = try #require(doc["fittings"] as? [[String: Any]])
    let index = try #require(records.firstIndex { ($0["id"] as? String) == "2A" })
    var rule = try #require(records[index]["rule"] as? [String: Any])
    var rows = try #require(rule["rows"] as? [[String: Any]])
    rows.remove(at: 2)
    rule["rows"] = rows
    records[index]["rule"] = rule
    doc["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(
      throws: CatalogValidator.ValidationError(
        message: "Branch buckets must be contiguous from zero")
    ) {
      try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
    }
  }

  @Test func duplicateJunctionPathsAreRejected() throws {
    var doc = try document()
    var records = try #require(doc["fittings"] as? [[String: Any]])
    let index = try #require(records.firstIndex { ($0["id"] as? String) == "9A" })
    var rule = try #require(records[index]["rule"] as? [String: Any])
    var rows = try #require(rule["rows"] as? [[String: Any]])
    rows[1]["path"] = "branch"
    rule["rows"] = rows
    records[index]["rule"] = rule
    doc["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(
      throws: CatalogValidator.ValidationError(
        message: "Junction must have one row for each path in canonical order")
    ) {
      try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
    }
  }

  @Test func assetTraversalIsRejected() throws {
    var doc = try document()
    var records = try #require(doc["fittings"] as? [[String: Any]])
    var art = try #require(records[0]["artwork"] as? [String: Any])
    art["publicPath"] = "/images/fittings/../../secrets.svg"
    records[0]["artwork"] = art
    doc["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(
      throws: CatalogValidator.ValidationError(message: "Artwork must be a catalog-owned SVG path")
    ) {
      try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
    }
  }

  @Test(arguments: ["8H", "8K", "8P"])
  func alteredOffsetCoverageIsRejected(id: String) throws {
    var doc = try document()
    var records = try #require(doc["fittings"] as? [[String: Any]])
    let index = try #require(records.firstIndex { ($0["id"] as? String) == id })
    var rule = try #require(records[index]["rule"] as? [String: Any])
    var rows = try #require(rule["rows"] as? [[String: Any]])
    switch id {
    case "8H": rows[0]["vanedFeet"] = 55 // The source has a dash, not a usable length.
    case "8K": rows.removeFirst() // Mitered R/H = 0 is a supported source row.
    default: rows[1]["riserCorner"] = "miter" // Must retain both corner constructions.
    }
    rule["rows"] = rows
    records[index]["rule"] = rule
    doc["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(throws: CatalogValidator.ValidationError.self) {
      try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
    }
  }

  @Test(arguments: ["duplicateView", "alternateTraversal", "unorderedAirflow", "wrongAdjustment"])
  func invalidPannedReturnMetadataIsRejected(fault: String) throws {
    var doc = try document()
    var records = try #require(doc["fittings"] as? [[String: Any]])
    let index = try #require(records.firstIndex { ($0["id"] as? String) == "7C" })
    let message: String
    switch fault {
    case "duplicateView":
      records[index]["alternateArtwork"] = [records[index]["artwork"]]
      message = "Duplicate artwork view"
    case "alternateTraversal":
      var arts = try #require(records[index]["alternateArtwork"] as? [[String: Any]])
      arts[0]["publicPath"] = "/images/fittings/../../invalid.svg"
      records[index]["alternateArtwork"] = arts
      message = "Artwork must be a catalog-owned SVG path"
    case "unorderedAirflow":
      var rule = try #require(records[index]["rule"] as? [String: Any])
      let rows = try #require(rule["rows"] as? [[String: Any]])
      rule["rows"] = Array(rows.reversed())
      records[index]["rule"] = rule
      message = "Panned return airflow rows must be positive whole CFM in increasing order"
    default:
      var rule = try #require(records[index]["rule"] as? [String: Any])
      rule["mergingFlowFeet"] = 20
      records[index]["rule"] = rule
      message = "Unexpected merging-flow adjustment"
    }
    doc["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(throws: CatalogValidator.ValidationError(message: message)) {
      try CatalogValidator.validate(JSONDecoder().decode(Catalog.Document.self, from: data))
    }
  }
}
