import Foundation
import ManualDCore

public enum CatalogReviewError: Error, Equatable, Sendable, CustomStringConvertible {
  case disabled, stale, invalidChanges, unsupportedFormatting
  public var description: String {
    switch self {
    case .disabled: "Catalog review is not enabled on this server."
    case .stale:
      "The catalog changed since this page loaded. Reload before saving; your selections are still on this page."
    case .invalidChanges: "The review contains an unknown, duplicate, or invalid fitting."
    case .unsupportedFormatting:
      "The catalog formatting changed. No file was written; review the source file before retrying."
    }
  }
}

/// Development authoring only. Serializes review writes and reloads external source edits.
/// Production clients continue using their immutable packaged catalog.
actor CatalogReviewStore {
  private let url: URL
  private var data: Data
  private var loaded: Catalog
  private var version = UUID().uuidString

  init(path: String) throws {
    url = URL(fileURLWithPath: path)
    data = try Data(contentsOf: url)
    loaded = try Catalog(data: data)
  }

  func catalog() throws -> Catalog {
    let current = try Data(contentsOf: url)
    if current != data {
      let next = try Catalog(data: current)
      data = current
      loaded = next
      version = UUID().uuidString
    }
    return loaded
  }

  func review() throws -> Fitting.CatalogReview {
    let catalog = try catalog()
    return .init(
      version: version,
      entries: catalog.records.map { record in
        .init(
          id: record.id, groupID: record.groupID,
          groupTitle: catalog.groupRecords.first { $0.id == record.groupID }!.title,
          name: record.name, sourceCode: record.sourceCode, artwork: record.artwork,
          ductShape: record.ductShape, reviewed: record.ductShapeReviewed)
      })
  }

  func save(_ submission: Fitting.CatalogReviewSave) throws -> Fitting.CatalogReview {
    let current = try catalog()
    guard submission.version == version else { throw CatalogReviewError.stale }
    guard !submission.changes.isEmpty, submission.changes.count <= current.records.count,
      Set(submission.changes.map(\.id)).count == submission.changes.count,
      submission.changes.allSatisfy({ current.byID[$0.id] != nil })
    else { throw CatalogReviewError.invalidChanges }
    guard var text = String(data: data, encoding: .utf8),
      var expected = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      var records = expected["fittings"] as? [[String: Any]]
    else { throw CatalogReviewError.invalidChanges }

    for change in submission.changes {
      let id = NSRegularExpression.escapedPattern(for: change.id.rawValue)
      let pattern =
        "(?ms)(^      \"id\": \"\(id)\",\\n.*?^      \"ductShape\": \")[^\"]+(\",\\n      \"ductShapeReviewed\": )(?:true|false)"
      let regex = try NSRegularExpression(pattern: pattern)
      let range = NSRange(text.startIndex..., in: text)
      guard regex.numberOfMatches(in: text, range: range) == 1 else {
        throw CatalogReviewError.unsupportedFormatting
      }
      text = regex.stringByReplacingMatches(
        in: text, range: range,
        withTemplate: "$1\(change.ductShape.rawValue)$2\(change.reviewed)")
      let index = records.firstIndex { $0["id"] as? String == change.id.rawValue }!
      records[index]["ductShape"] = change.ductShape.rawValue
      records[index]["ductShapeReviewed"] = change.reviewed
    }
    expected["fittings"] = records
    let nextData = Data(text.utf8)
    // Prove the surgical text edit changed only the requested metadata, preserving
    // every other JSON value and the file's existing order/formatting for Git review.
    guard let actual = try JSONSerialization.jsonObject(with: nextData) as? [String: Any],
      NSDictionary(dictionary: actual).isEqual(NSDictionary(dictionary: expected))
    else { throw CatalogReviewError.unsupportedFormatting }
    let next = try Catalog(data: nextData)
    guard try Data(contentsOf: url) == data else { throw CatalogReviewError.stale }
    if nextData != data {
      try nextData.write(to: url, options: .atomic)
      data = nextData
      loaded = next
      version = UUID().uuidString
    }
    return try review()
  }
}
