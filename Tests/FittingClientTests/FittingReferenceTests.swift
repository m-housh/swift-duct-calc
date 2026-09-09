import Dependencies
import FileClient
import Foundation
import ManualDCore
import Testing
import URLRouting

@testable import FittingClient

struct FittingReferenceTests {
  let catalog: FittingReference

  init() async throws {
    let client = try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    } operation: {
      try await FittingClient.live()
    }
    catalog = try client.reference()
  }

  @Test func filteringAndPathApplicability() {
    #expect(catalog.entries.count == 231)
    #expect(catalog.filter(group: "13").isEmpty)
    #expect(catalog.filter(group: "2").count == 17)
    #expect(catalog.filter(query: "8a smooth").count == 2)
    #expect(catalog.filter(group: "1", query: "8a").isEmpty)
    #expect(catalog.filter(query: "no-such-fitting").isEmpty)
    #expect(catalog.filter(type: "fixed").allSatisfy { $0.isFixed })
    #expect(catalog.filter(type: "conditional").allSatisfy { !$0.isFixed })
    #expect(catalog.groups(for: "supply").map(\.id) == [1, 2, 3, 4, 8, 9, 11, 12])
    #expect(catalog.groups(for: "return").map(\.id) == [5, 6, 7, 8, 10, 11, 12])
  }

  @Test func normalizesQueriesAndPreservesShareableState() throws {
    let invalid = try page(
      .init(
        system: "invalid", group: "999", fitting: "missing", type: "wrong", data: "invalid",
        scope: "invalid"))
    #expect(invalid.system == "all")
    #expect(invalid.group == "1")
    #expect(invalid.selected?.id == "1A")
    #expect(invalid.type == "all")
    #expect(!invalid.showData)
    let returning = try page(.init(system: "return", group: "1"))
    #expect(returning.group == "5")
    #expect(returning.rows.allSatisfy { $0.record.group == 5 })
    let inferred = try page(.init(fitting: "8A-smooth", data: "csv", scope: "filtered"))
    #expect(inferred.group == "8")
    #expect(inferred.selected?.id == "8A-smooth")
    #expect(inferred.showData)
    let route = try SiteRoute.View.router.parse(URLRequestData(string: inferred.path())!)
    guard case .fittingReference(let query) = route else {
      Issue.record("Wrong route")
      return
    }
    #expect(query.scope == "filtered")
    #expect(query.data == "csv")
    #expect(try page(query).exportText == inferred.exportText)
    let plus = try page(.init(q: "8a+smooth"))
    #expect(plus.path().contains("q=8a%2Bsmooth"))
    let empty = try page(.init(q: "<script>does not exist</script>", data: "json"))
    #expect(empty.selected == nil)
    #expect(empty.exportText.isEmpty)
  }

  @Test func guestsCannotEnableInspectorAndLoginRetainsRequestedFormat() throws {
    let guest = try FittingReferencePage(
      catalog: catalog, query: .init(system: "return", fitting: "8A-smooth", data: "csv"),
      isLoggedIn: false)
    #expect(!guest.showData)
    #expect(guest.exportText.isEmpty)
    let login = URLComponents(string: guest.loginPath)!
    let continuation = login.queryItems!.first { $0.name == "next" }!.value!
    #expect(continuation.contains("data=csv"))
    #expect(continuation.contains("fitting=8A-smooth"))
    #expect(continuation.contains("system=return"))
  }

  @Test func allExportedRecordsMatchTheSourceIncludingExplicitNulls() throws {
    let source = try sourceDocument()
    let entries = source["entries"] as! [[String: Any]]
    let expected = entries.map { $0["record"] as! [String: Any] }
    let json = try FittingReference.export(catalog.entries, format: "json")
    let actual = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    #expect(NSArray(array: actual["fittings"] as! [Any]) == NSArray(array: expected))
    #expect(actual["schema"] as? String == "duct-calc.fitting-reference.prototype.v1")
    let csv = try parseCSV(FittingReference.export(catalog.entries, format: "csv"))
    #expect(csv.count == 232)
    let columns = csv[0]
    for (row, entry) in zip(csv.dropFirst(), expected) {
      let record = Dictionary(uniqueKeysWithValues: zip(columns, row))
      #expect(record["id"] == entry["id"] as? String)
      let reference =
        try JSONSerialization.jsonObject(with: Data(record["reference_json"]!.utf8))
        as! NSDictionary
      #expect(reference == entry["reference"] as! NSDictionary)
    }
  }

  @Test func csvQuotesCommasQuotesAndNewlines() throws {
    var source = try sourceDocument()
    var entries = source["entries"] as! [[String: Any]]
    var first = entries[0]["record"] as! [String: Any]
    let name = "Test, \"quoted\"\nmultiline name"
    first["name"] = name
    entries[0]["record"] = first
    source["entries"] = entries
    let fixture = try FittingReference(
      data: JSONSerialization.data(withJSONObject: source), pathGroups: [:])
    let csv = try parseCSV(FittingReference.export([fixture.entries[0]], format: "csv"))
    #expect(csv[1][csv[0].firstIndex(of: "name")!] == name)
  }

  @Test func pathExampleAlwaysUsesSelectedFittingAndSourceConditions() throws {
    let conditional = try page(.init(fitting: "8A-smooth", data: "path", scope: "filtered"))
    #expect(conditional.scope == "record")
    let export =
      try JSONSerialization.jsonObject(with: Data(conditional.exportText.utf8)) as! [String: Any]
    let entry = (export["entries"] as! [[String: Any]])[0]
    #expect(entry["fitting_id"] as? String == "8A-smooth")
    #expect(entry["reference_equivalent_length_ft"] is NSNull)
    #expect(!(entry["conditions"] as! [String: Any]).isEmpty)
    let fixed = try page(.init(fitting: "1A", data: "path"))
    #expect(fixed.exportText.contains("35"))
  }

  private func page(_ query: SiteRoute.View.FittingsQuery) throws -> FittingReferencePage {
    try .init(catalog: catalog, query: query, isLoggedIn: true)
  }

  private func sourceDocument() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    return try JSONSerialization.jsonObject(
      with: Data(
        contentsOf: root.appendingPathComponent("Sources/FittingClient/Resources/reference.json")))
      as! [String: Any]
  }

  private func parseCSV(_ text: String) throws -> [[String]] {
    let bytes = Array(text.utf8)
    var rows: [[String]] = []
    var row: [String] = []
    var cell: [UInt8] = []
    var quoted = false
    var index = 0
    while index < bytes.count {
      let byte = bytes[index]
      if byte == 34 {
        if quoted && index + 1 < bytes.count && bytes[index + 1] == 34 {
          cell.append(34)
          index += 1
        } else {
          quoted.toggle()
        }
      } else if byte == 44 && !quoted {
        row.append(String(decoding: cell, as: UTF8.self))
        cell = []
      } else if byte == 13 && !quoted && index + 1 < bytes.count && bytes[index + 1] == 10 {
        row.append(String(decoding: cell, as: UTF8.self))
        rows.append(row)
        row = []
        cell = []
        index += 1
      } else {
        cell.append(byte)
      }
      index += 1
    }
    #expect(!quoted)
    return rows
  }
}
