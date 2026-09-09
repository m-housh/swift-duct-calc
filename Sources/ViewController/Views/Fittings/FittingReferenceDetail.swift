import Elementary
import FittingClient
import Foundation

struct FittingReferenceDetail: HTML, Sendable {
  let entry: FittingReference.Entry
  let page: FittingReferencePage

  var body: some HTML {
    article(.class("detail")) {
      div(.class("breadcrumb")) {
        "GROUP \(String(format: "%02d", entry.record.group))"
        span { "/" }
        page.catalog.groups.first { $0.id == entry.record.group }?.name ?? ""
      }
      div(.class("detail-heading")) {
        div {
          span(.class("fitting-code")) { entry.record.source_fitting_code }
          h2 { entry.record.name }
        }
        span(.class("reference-badge \(entry.isFixed ? "" : "conditional")")) {
          entry.isConcept ? "Concept" : entry.isFixed ? "Fixed reference" : "Requires conditions"
        }
      }
      div(.class("artboard")) {
        FittingReferenceDrawing(entry: entry)
        span(.class("art-label")) {
          entry.isConcept ? "CONCEPT ILLUSTRATION" : "INDIVIDUAL FITTING DRAWING"
        }
      }
      div(.class("identity")) {
        div {
          span(.class("eyebrow")) { "CATALOG ID" }
          code { entry.id }
        }
        button(.class("text-button browser-only"), .data("copy-id", value: entry.id)) { "Copy ID" }
        button(
          .class("text-button browser-only"), .data("action", value: "share"),
          .data(
            "share-path",
            value: page.path(["group": String(entry.record.group), "q": "", "type": ""]))
        ) { "Copy link ↗" }
      }
      div(.class("detail-columns")) {
        section {
          h3 { "Reference values" }
          referenceTable
        }
        section {
          h3 { "Conditions" }
          conditions
        }
      }
      if !entry.applicationNotes.isEmpty {
        section(.class("notes")) {
          h3 { "Application notes" }
          ul { for note in entry.applicationNotes { li { note } } }
        }
      }
      div(.class("source-line")) {
        span { "ACCA Manual D · printed page \(entry.record.source.printed_page)" }
        if page.isLoggedIn {
          a(
            .class("text-button"), .href(page.path(["data": "json", "scope": "record"])),
            .data("reference-nav", value: ""), .data("record", value: entry.id)
          ) { "View JSON / CSV →" }
        }
      }
      p(.class("audit-note")) {
        "\(entry.isConcept ? "Concept artwork" : "Visually approved artwork") · reference transcription, not an audited calculation rule."
      }
    }
  }

  private var referenceTable: some HTML {
    let source = entry.record.reference.table
    let hasNotes = source.rows.contains { $0.note != nil && $0.note != "" }
    return div(.class("source-table-wrap")) {
      if source.rows.isEmpty {
        p(.class("notice")) {
          "No supported reference table is available. This fitting cannot supply a reference value."
        }
      } else {
        table(.class("source-table")) {
          caption {
            entry.isConcept
              ? "Junction box only · sidewall openings" : "Equivalent length at listed conditions"
          }
          thead {
            tr {
              for label in source.labels { th(.custom(name: "scope", value: "col")) { label } }
              th(.custom(name: "scope", value: "col")) { "EL (ft)" }
              if hasNotes { th(.custom(name: "scope", value: "col")) { "Note" } }
            }
          }
          tbody {
            for row in source.rows {
              tr {
                for key in row.keys { td { key } }
                td(.class("numeric")) { FittingReference.Value.number(row.value).text }
                if hasNotes { td { row.note ?? "" } }
              }
            }
          }
        }
      }
    }
  }

  private var conditions: some HTML {
    dl(.class("conditions")) {
      for key in entry.record.reference.conditions.keys.sorted() {
        div {
          dt { conditionLabel(key) }
          dd { entry.record.reference.conditions[key]?.text ?? "" }
        }
      }
      if entry.record.reference.conditions.isEmpty {
        p(.class("muted")) { "No reference conditions are recorded for this fitting." }
      }
    }
  }

  private func conditionLabel(_ key: String) -> String {
    switch key {
    case "velocityFpm": return "Reference velocity (FPM)"
    case "frictionRateIwcPer100Feet": return "Friction rate (IWC / 100 ft)"
    default:
      let text = key.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
      return text.prefix(1).uppercased() + text.dropFirst()
    }
  }
}
