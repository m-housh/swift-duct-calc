import Foundation
import ManualDCore

/// Parses UTF-8 CSV with quoted fields, escaped quotes, and physical source line numbers.
public enum FittingCSVParser {
  public static func parse(_ text: String) -> FittingCSV {
    var result = FittingCSV()
    func issue(_ line: Int, _ field: String, _ message: String) {
      result.issues.append(.init(line: line, field: field, message: message))
    }
    guard text.utf8.count <= FittingCSV.byteLimit else {
      issue(1, "file", "Use a CSV of at most 64 KiB.")
      return result
    }
    // Normalize record separators before scanning. Newlines inside quotes remain field content.
    var source = text.replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    if source.first == "\u{feff}" { source.removeFirst() }
    enum State { case field, quoted, closed }
    var state = State.field
    var records: [(line: Int, fields: [String])] = []
    var fields: [String] = []
    var field = ""
    var line = 1
    var startLine = 1
    var hasContent = false
    func endField() {
      fields.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
      field = ""
      state = .field
    }
    func endRecord() {
      endField()
      if hasContent { records.append((startLine, fields)) }
      fields = []
      hasContent = false
    }
    for character in source {
      if state == .quoted {
        if character == "\"" { state = .closed } else { field.append(character) }
      } else if character == "," {
        hasContent = true
        endField()
      } else if character == "\n" {
        endRecord()
        startLine = line + 1
      } else if character == "\"" {
        hasContent = true
        if state == .closed {
          field.append(character)
          state = .quoted
        } else if field.trimmingCharacters(in: .whitespaces).isEmpty {
          field = ""
          state = .quoted
        } else {
          issue(line, "CSV", "Unexpected quote in an unquoted field.")
          return result
        }
      } else if state == .closed {
        if character != " " && character != "\t" {
          issue(line, "CSV", "Expected a comma or newline after the closing quote.")
          return result
        }
      } else {
        field.append(character)
        if !character.isWhitespace { hasContent = true }
      }
      if character == "\n" { line += 1 }
    }
    guard state != .quoted else {
      issue(startLine, "CSV", "Unclosed quoted field.")
      return result
    }
    endRecord()
    guard let header = records.first else {
      issue(1, "header", "Include code,length_ft and optional quantity column headers.")
      return result
    }
    guard Set(header.fields).isSubset(of: ["code", "length_ft", "quantity"]),
      Set(header.fields).count == header.fields.count,
      let codeIndex = header.fields.firstIndex(of: "code"),
      let feetIndex = header.fields.firstIndex(of: "length_ft")
    else {
      issue(
        header.line, "header",
        "Use code,length_ft and optional quantity, with no duplicate or extra columns.")
      return result
    }
    guard records.count > 1, records.count <= FittingCSV.rowLimit + 1 else {
      issue(header.line, "file", "Include between 1 and 500 fitting rows.")
      return result
    }
    let quantityIndex = header.fields.firstIndex(of: "quantity")
    for record in records.dropFirst() {
      guard record.fields.count == header.fields.count else {
        issue(record.line, "CSV", "The number of fields must match the header.")
        continue
      }
      let code = record.fields[codeIndex]
      let length = record.fields[feetIndex]
      let quantityText = quantityIndex.map { record.fields[$0] } ?? ""
      let quantity = quantityText.isEmpty ? 1 : Int(quantityText)
      let feet = Double(length)
      let initialIssues = result.issues.count
      if code.isEmpty || code.count > 64 {
        issue(record.line, "code", "Enter a fitting code of at most 64 characters.")
      }
      if feet == nil || !feet!.isFinite || feet! <= 0 {
        issue(
          record.line, "length_ft", "Enter positive, finite feet per fitting using a decimal point."
        )
      }
      if quantity == nil || quantity! < 1 || quantity! > 1_000_000
        || (!quantityText.isEmpty && !quantityText.utf8.allSatisfy({ (48...57).contains($0) }))
      {
        issue(
          record.line, "quantity",
          "Enter a whole number between 1 and 1,000,000, or leave empty for 1.")
      }
      guard initialIssues == result.issues.count, let feet, let quantity else { continue }
      guard (feet * Double(quantity)).isFinite else {
        issue(record.line, "length_ft", "The row subtotal is too large.")
        continue
      }
      result.rows.append(.init(line: record.line, code: code, feet: feet, quantity: quantity))
    }
    return result
  }
}
