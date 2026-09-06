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
}
