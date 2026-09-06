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

  @Test func duplicateIDsFailAsInfrastructureError() throws {
    var doc = try document()
    var records = try #require(doc["fittings"] as? [[String: Any]])
    records.append(records[0])
    doc["fittings"] = records
    let data = try JSONSerialization.data(withJSONObject: doc)
    #expect(throws: FittingClientError.invalidCatalog("Duplicate fitting ID")) {
      try Catalog(data: data)
    }
  }

  @Test func malformedTablesAreRejectedBeforeEvaluation() throws {
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
      throws: FittingClientError.invalidCatalog("Branch buckets must be contiguous from zero")
    ) {
      try Catalog(data: data)
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
    #expect(throws: FittingClientError.invalidCatalog("Artwork must be a catalog-owned SVG path")) {
      try Catalog(data: data)
    }
  }
}
