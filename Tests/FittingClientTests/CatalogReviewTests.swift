import Dependencies
import FileClient
import Foundation
import ManualDCore
import Testing

@testable import FittingClient

struct CatalogReviewTests {
  private func reviewClient(path: String) async throws -> FittingClient {
    try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    } operation: {
      try await FittingClient.live(reviewCatalogPath: path)
    }
  }

  func fixture() throws -> URL {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "catalog-review-\(UUID()).json")
    // Review tests start with pending records in their disposable copy, regardless
    // of how much of the authored catalog has already been reviewed.
    let source = try String(
      contentsOf: root.appendingPathComponent("Sources/FittingClient/Resources/catalog.json"),
      encoding: .utf8)
    try Data(
      source.replacingOccurrences(
        of: "\"ductShapeReviewed\": true", with: "\"ductShapeReviewed\": false"
      ).utf8
    )
    .write(to: url)
    return url
  }

  @Test func savesOnlyMetadataAndBothClientsReadTheSameClassification() async throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let before = try Data(contentsOf: url)
    let client = try await reviewClient(path: url.path)
    let review = try await client.catalogReview()
    #expect(client.catalogReviewEnabled())
    let evaluation = try await client.evaluate(
      .init(pathType: .supply, fittingID: "4A", inputs: .fixed))
    let saved = try await client.saveCatalogReview(
      .init(
        version: review.version,
        changes: [
          .init(id: "4A", ductShape: .round, reviewed: true)
        ]))
    #expect(saved.version != review.version)
    let after = try Data(contentsOf: url)
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var records = try #require(expected["fittings"] as? [[String: Any]])
    let index = try #require(records.firstIndex { $0["id"] as? String == "4A" })
    records[index]["ductShape"] = "round"
    records[index]["ductShapeReviewed"] = true
    expected["fittings"] = records
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(NSDictionary(dictionary: expected)))
    // Keep review diffs surgical: one shape line and one review-status line.
    let oldLines = String(decoding: before, as: UTF8.self).components(separatedBy: "\n")
    let newLines = String(decoding: after, as: UTF8.self).components(separatedBy: "\n")
    #expect(oldLines.count == newLines.count)
    #expect(zip(oldLines, newLines).filter { $0 != $1 }.count == 2)
    let definition = try #require(
      try await client.fittings(.init(pathType: .supply, groupID: .supplyBoots)).first {
        $0.id == "4A"
      })
    #expect(definition.ductShape == .round && definition.ductShapeReviewed)
    #expect(
      try await client.evaluate(.init(pathType: .supply, fittingID: "4A", inputs: .fixed))
        == evaluation)
    let packaged = try await withDependencies {
      $0.fileClient.readFile = { path in
        path.hasSuffix("/catalog.json") ? after : try Data(contentsOf: URL(fileURLWithPath: path))
      }
    } operation: {
      try await FittingClient.live()
    }
    let packagedDefinition = try #require(
      try await packaged.fittings(.init(pathType: .supply, groupID: .supplyBoots)).first {
        $0.id == "4A"
      })
    #expect(packagedDefinition == definition)
    #expect(!packaged.catalogReviewEnabled())
    await #expect(throws: CatalogReviewError.disabled) { try await packaged.catalogReview() }
    await #expect(throws: CatalogReviewError.disabled) {
      try await packaged.saveCatalogReview(.init(version: saved.version, changes: []))
    }
  }

  @Test func staleAndInvalidSubmissionsCannotChangeTheFile() async throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let client = try await reviewClient(path: url.path)
    let review = try await client.catalogReview()
    let saved = try await client.saveCatalogReview(
      .init(
        version: review.version,
        changes: [
          .init(id: "4A", ductShape: .rectangular, reviewed: true)
        ]))
    let bytes = try Data(contentsOf: url)
    await #expect(throws: CatalogReviewError.stale) {
      try await client.saveCatalogReview(
        .init(
          version: review.version, changes: [.init(id: "4A", ductShape: .round, reviewed: true)]))
    }
    for changes: [Fitting.CatalogReviewChange] in [
      [], [.init(id: "unknown", ductShape: .round, reviewed: true)],
      [
        .init(id: "4A", ductShape: .round, reviewed: true),
        .init(id: "4A", ductShape: .rectangular, reviewed: false),
      ],
    ] {
      await #expect(throws: CatalogReviewError.invalidChanges) {
        try await client.saveCatalogReview(.init(version: saved.version, changes: changes))
      }
    }
    #expect(try Data(contentsOf: url) == bytes)
    // External source edits invalidate old review pages as well.
    var external = bytes
    external.append(contentsOf: [10])
    try external.write(to: url)
    await #expect(throws: CatalogReviewError.stale) {
      try await client.saveCatalogReview(
        .init(version: saved.version, changes: [.init(id: "4A", ductShape: .round, reviewed: true)])
      )
    }
    #expect(try Data(contentsOf: url) == external)
  }

  @Test func concurrentReviewsCannotOverwriteTheSameBaseline() async throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let client = try await reviewClient(path: url.path)
    let review = try await client.catalogReview()
    func attempt(_ id: Fitting.ID) async -> Bool {
      do {
        _ = try await client.saveCatalogReview(
          .init(
            version: review.version,
            changes: [
              .init(id: id, ductShape: .rectangular, reviewed: true)
            ]))
        return true
      } catch {
        #expect(error as? CatalogReviewError == .stale)
        return false
      }
    }
    async let first = attempt("4A")
    async let second = attempt("4B")
    let successes = await [first, second].filter { $0 }
    #expect(successes.count == 1)
    let final = try await client.catalogReview()
    #expect(
      final.entries.filter { ["4A", "4B"].contains($0.id.rawValue) && $0.reviewed }.count == 1)
  }

  @Test func schemaRequiresExplicitDuctShapeAndReviewStatus() throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let data = try Data(contentsOf: url)
    for key in ["ductShape", "ductShapeReviewed"] {
      var document = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      var records = try #require(document["fittings"] as? [[String: Any]])
      records[0].removeValue(forKey: key)
      document["fittings"] = records
      let invalid = try JSONSerialization.data(withJSONObject: document)
      #expect(throws: FittingClientError.self) { try Catalog(data: invalid) }
    }
  }

  @Test func unexpectedFormattingFailsWithoutRewritingOtherContent() async throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let compact = try JSONSerialization.data(
      withJSONObject: JSONSerialization.jsonObject(with: Data(contentsOf: url)))
    try compact.write(to: url)
    let client = try await reviewClient(path: url.path)
    let review = try await client.catalogReview()
    await #expect(throws: CatalogReviewError.unsupportedFormatting) {
      try await client.saveCatalogReview(
        .init(
          version: review.version, changes: [.init(id: "4A", ductShape: .round, reviewed: true)]))
    }
    #expect(try Data(contentsOf: url) == compact)
  }
}
