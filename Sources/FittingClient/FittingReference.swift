import Foundation
import ManualDCore

/// Source transcription for browsing and export. Project calculations use FittingClient.evaluate.
public struct FittingReference: Sendable {
  public struct Group: Codable, Sendable {
    public let id: Int
    public let name: String
    public let title: String
  }

  public struct Entry: Codable, Sendable {
    public let record: Record
    public let viewport: [Double]?
    public let additionalNotes: [String]
    public var applicationNotes: [String] {
      record.reference.notes
        + (record.reference.counting_rule == .null ? [] : [record.reference.counting_rule.text])
        + additionalNotes
    }
    public var id: String { record.id }
    public var isConcept: Bool { record.artwork_status == "concept" }
    public var isFixed: Bool { record.reference.fixed_equivalent_length_ft != .null }
    public var imagePath: String { String(record.image_url.split(separator: "#")[0]) }
  }

  // Field names retain the existing experimental export contract.
  public struct Record: Codable, Sendable {
    public let id: String
    public let source_fitting_code: String
    public let group: Int
    public let name: String
    public let variant: Value
    public let shape: Value
    public let view: Value
    public let artwork_status: String
    public let image_url: String
    public let reference: Reference
    public let source: Source
  }

  public struct Reference: Codable, Sendable {
    public let units: String
    public let fixed_equivalent_length_ft: Value
    public let conditions: [String: Value]
    public let table: Table
    public let source_values: Value
    public let ratio_table: Value
    public let downstream_branches: Value
    public let adjustment: Value
    public let counting_rule: Value
    public let notes: [String]
    public let calculation_status: String
  }

  public struct Table: Codable, Sendable {
    public struct Row: Codable, Sendable {
      public let keys: [String]
      public let value: Double
      public let note: String?
    }
    public let labels: [String]
    public let rows: [Row]
  }

  public struct Source: Codable, Sendable {
    public let document: String
    public let printed_page: String
  }

  /// Heterogeneous source conditions remain lossless, including explicit nulls in exports.
  public enum Value: Codable, Equatable, Sendable {
    case null
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([Value])
    case object([String: Value])

    public init(from decoder: Decoder) throws {
      let value = try decoder.singleValueContainer()
      if value.decodeNil() {
        self = .null
      } else if let x = try? value.decode(Bool.self) {
        self = .bool(x)
      } else if let x = try? value.decode(Double.self) {
        self = .number(x)
      } else if let x = try? value.decode(String.self) {
        self = .string(x)
      } else if let x = try? value.decode([Value].self) {
        self = .array(x)
      } else {
        self = .object(try value.decode([String: Value].self))
      }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .null: try container.encodeNil()
      case .string(let x): try container.encode(x)
      case .number(let x): try container.encode(x)
      case .bool(let x): try container.encode(x)
      case .array(let x): try container.encode(x)
      case .object(let x): try container.encode(x)
      }
    }

    public var text: String {
      switch self {
      case .null: return ""
      case .string(let text): return text
      default: return (try? FittingReference.json(self, pretty: false)) ?? ""
      }
    }
  }

  private let pathGroups: [Fitting.PathType: [Int]]
  public let groups: [Group]
  public let entries: [Entry]

  init(data: Data, pathGroups: [Fitting.PathType: [Int]]) throws {
    struct Document: Decodable {
      let schemaVersion: Int
      let groups: [Group]
      let entries: [Entry]
    }
    let document: Document
    do { document = try JSONDecoder().decode(Document.self, from: data) } catch {
      throw FittingClientError.invalidCatalog("Cannot decode reference: \(error)")
    }
    groups = document.groups
    entries = document.entries
    self.pathGroups = pathGroups
    guard document.schemaVersion == 1,
      Set(entries.map(\.id)).count == entries.count,
      Set(groups.map(\.id)) == Set(1...12), groups.count == 12,
      entries.allSatisfy({ entry in
        groups.contains { $0.id == entry.record.group }
          && !entry.record.image_url.isEmpty
          && (entry.viewport == nil || entry.viewport?.count == 4)
          && entry.record.reference.table.rows.allSatisfy {
            $0.keys.count == entry.record.reference.table.labels.count && $0.value.isFinite
          }
      })
    else { throw FittingClientError.invalidCatalog("Invalid reference catalog structure") }
  }

  public func groups(for system: String) -> [Group] {
    // Use the same path applicability as the calculation catalog's shared group identities.
    guard let path = Fitting.PathType(rawValue: system) else { return groups }
    return groups.filter { group in
      pathGroups[path, default: []].contains(group.id)
    }
  }

  public func filter(
    group: String = "all", query: String = "", type: String = "all", system: String = "all"
  ) -> [Entry] {
    let eligible = Set(groups(for: system).map(\.id))
    let terms = query.lowercased().split(whereSeparator: \.isWhitespace)
    return entries.filter { entry in
      let r = entry.record
      guard eligible.contains(r.group), group == "all" || Int(group) == r.group,
        type == "all" || (type == "fixed" ? entry.isFixed : !entry.isFixed)
      else { return false }
      let title = groups.first { $0.id == r.group }?.title ?? ""
      let text =
        ([r.id, r.source_fitting_code, r.name, r.variant.text, r.shape.text, r.view.text, title]
        + r.reference.notes).joined(separator: " ").lowercased()
      return terms.allSatisfy { text.contains($0) }
    }
  }

  public static func json<T: Encodable>(_ value: T, pretty: Bool = true) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting =
      pretty
      ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      : [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  public static func export(_ entries: [Entry], format: String) throws -> String {
    if format == "csv" {
      let columns = [
        "id", "source_fitting_code", "group", "name", "variant", "shape", "artwork_status",
        "fixed_equivalent_length_ft", "conditions_json", "reference_json", "source_json",
        "image_url",
      ]
      let rows = try entries.map { entry in
        let r = entry.record
        return [
          r.id, r.source_fitting_code, String(r.group), r.name, r.variant.text, r.shape.text,
          r.artwork_status, r.reference.fixed_equivalent_length_ft.text,
          try json(r.reference.conditions, pretty: false), try json(r.reference, pretty: false),
          try json(r.source, pretty: false), r.image_url,
        ]
      }
      return ([columns] + rows).map { row in
        row.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(
          separator: ",")
      }.joined(separator: "\r\n") + "\r\n"
    }
    if format == "path", let entry = entries.first {
      let r = entry.record
      let conditions =
        entry.isFixed
        ? [:] : Dictionary(uniqueKeysWithValues: r.reference.table.labels.map { ($0, Value.null) })
      return try json(
        Value.object([
          "schema": .string("duct-calc.path-example.prototype.v1"),
          "status": .string("Illustrative only; no production import or API endpoint exists here"),
          "entries": .array([
            .object([
              "sequence": .number(1), "fitting_id": .string(r.id), "quantity": .number(1),
              "conditions": .object(conditions),
              "reference_equivalent_length_ft": r.reference.fixed_equivalent_length_ft,
              "resolution": .string(
                entry.isFixed
                  ? "Fixed at the catalog reference conditions"
                  : "Select the required source conditions before resolving a value"),
            ])
          ]),
        ]))
    }
    struct Export: Encodable {
      let schema = "duct-calc.fitting-reference.prototype.v1"
      let status = "reference-only; not a production API or import contract"
      let fittings: [Record]
    }
    return try json(Export(fittings: entries.map(\.record)))
  }
}
