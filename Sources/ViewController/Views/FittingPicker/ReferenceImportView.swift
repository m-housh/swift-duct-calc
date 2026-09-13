import CSVParser
import Dependencies
import Elementary
import FittingClient
import Foundation
import ManualDCore
import Styleguide

struct ReferenceImportSubmission: Decodable {
  let csv: String
  let pathType: Fitting.PathType
  let entries: [PathEditorRow]
  let straightFeet: Double
}

extension SiteRoute.View.FittingPickerRoute {
  func previewReferenceImport(_ payload: String) async throws -> ReferenceImportPreview {
    @Dependency(\.fittingClient) var client
    let submission = try Self.decode(ReferenceImportSubmission.self, payload, limit: 1_500_000)
    guard submission.entries.count <= FittingCSV.rowLimit,
      submission.straightFeet.isFinite, submission.straightFeet >= 0,
      submission.entries.allSatisfy({
        $0.quantity > 0 && $0.quantity <= 1_000_000 && $0.row.feet.isFinite && $0.row.feet >= 0
      })
    else { throw PickerError("Check the existing path before importing fittings.") }
    let parsed = FittingCSVParser.parse(submission.csv)
    var preview = ReferenceImportPreview(issues: parsed.issues)
    for row in parsed.rows {
      switch try await client.resolveReference(.init(code: row.code, pathType: submission.pathType))
      {
      case .recognized(let reference):
        preview.rows.append(
          .init(
            line: row.line,
            entry: .init(
              id: "import-\(row.line)", quantity: row.quantity, savedIndex: nil,
              row: .init(
                name: "Reference entry", sourceCode: reference.code.rawValue,
                groupID: reference.groupID.rawValue, origin: "referenceEntry", feet: row.feet))))
      case .ineligible:
        preview.issues.append(
          .init(
            line: row.line, field: "code", message: "\(row.code) belongs to a different path type.")
        )
      case .unknown:
        preview.issues.append(
          .init(
            line: row.line, field: "code",
            message:
              "Unrecognized code \(row.code). Check your reference. Group 11 requires the fitting picker."
          ))
      }
    }
    let combined = submission.entries + preview.rows.map(\.entry)
    if combined.count > FittingCSV.rowLimit {
      preview.issues.append(
        .init(line: 1, field: "file", message: "The combined path can contain at most 500 rows."))
    }
    preview.proposedTotal = combined.reduce(submission.straightFeet) {
      $0 + $1.row.feet * Double($1.quantity)
    }
    if !preview.proposedTotal.isFinite {
      preview.issues.append(
        .init(line: 1, field: "length_ft", message: "The combined path total is too large."))
    }
    var counts: [Int: Int] = [:]
    for entry in combined { counts[entry.row.groupID, default: 0] += entry.quantity }
    preview.repeatedGroups = [1, 2, 3, 5, 6].filter { counts[$0, default: 0] > 1 }
    preview.issues.sort { $0.line < $1.line }
    return preview
  }
}

struct ReferenceImportView: HTML, Sendable {
  var body: some HTML {
    PickerDialog(id: "reference-import-dialog", title: "Import reference fittings") {
      p { "Paste CSV or load a CSV file, then review before adding to this path." }
      p {
        "Enter equivalent length per fitting in feet. Quantity defaults to 1. Your supplied lengths are preserved."
      }
      form(.id("reference-import-form")) {
        label {
          "Upload CSV"
          input(.type(.file), .id("reference-import-file"), .accept(".csv,text/csv"))
        }
        label {
          "Paste or edit CSV"
          textarea(
            .id("reference-import-csv"), .name("csv"), .required,
            .custom(name: "rows", value: "7"), .custom(name: "spellcheck", value: "false"),
            .placeholder("code,length_ft,quantity\n1A,35,\n4AG,30.5,2")
          ) {}
        }
        small {
          "UTF-8 CSV, up to 64 KiB and 500 rows including the current path. Headers: code,length_ft with optional quantity. Group 11 uses the fitting picker."
        }
        button(.type(.submit), .class("primary")) { "Preview import" }
      }
      div(.id("reference-import-result"), .custom(name: "aria-live", value: "polite")) {}
    }
  }
}

struct ReferenceImportPreview: HTML, Sendable {
  struct Row: Sendable {
    let line: Int
    let entry: PathEditorRow
  }
  var rows: [Row] = []
  var issues: [FittingCSV.Issue] = []
  var proposedTotal: Double = 0
  var repeatedGroups: [Int] = []
  var body: some HTML {
    if !issues.isEmpty {
      div(.class("fp-error"), .custom(name: "role", value: "alert")) {
        p { "Nothing has been added. Correct the CSV above and preview again." }
        ul {
          for issue in issues {
            li { "Line \(issue.line), \(issue.field): \(issue.message)" }
          }
        }
      }
    }
    if !rows.isEmpty {
      div(
        .class("reference-import-table"), .tabindex(0), .custom(name: "role", value: "region"),
        .custom(name: "aria-label", value: "CSV preview")
      ) {
        table {
          caption { "Recognized rows in CSV order" }
          thead {
            tr {
              for title in ["Line", "Code", "EL each (ft)", "Quantity", "Subtotal (ft)"] {
                th(.scope(.col)) { title }
              }
            }
          }
          tbody {
            for row in rows {
              tr {
                td { String(row.line) }
                td { row.entry.row.sourceCode ?? "" }
                td { pickerNumber(row.entry.row.feet) }
                td { String(row.entry.quantity) }
                td { pickerNumber(row.entry.row.feet * Double(row.entry.quantity)) }
              }
            }
          }
        }
      }
    }
    if issues.isEmpty && !rows.isEmpty {
      p {
        "Import total: \(pickerNumber(rows.reduce(0) { $0 + $1.entry.row.feet * Double($1.entry.quantity) })) ft"
      }
      p { "Proposed path total including straight duct: \(pickerNumber(proposedTotal)) ft" }
      for group in repeatedGroups {
        p(.class("coverage-warning")) {
          "Group \(group): check repeated use in the combined path. You can keep intentional duplicates."
        }
      }
      p {
        "Rows will be added to the draft and grouped by fitting group. Save the path to keep them."
      }
      button(
        .type(.button), .class("primary"), .id("reference-import-apply"),
        .data("import-rows", value: pickerJSON(rows.map(\.entry)))
      ) {
        "Add \(rows.count) rows to path"
      }
    }
  }
}
