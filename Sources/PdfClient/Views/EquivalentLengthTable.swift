import Elementary
import ManualDCore

struct EffectiveLengthTable: HTML, Sendable {
  let path: EquivalentLength

  var body: some HTML {
    section {
      h3(.class("path-heading")) {
        "\(path.type.rawValue.capitalized) · \(path.name)"
        span { "\(path.totalEquivalentLength.string()) ft TEL" }
      }
      table {
        thead {
          tr {
            ReportColumn("Fitting")
            ReportColumn("Length", unit: "ft")
            ReportColumn("Qty.")
            ReportColumn("Total", unit: "ft")
          }
        }
        tbody {
          for row in path.groups {
            tr {
              td { row.letter.isEmpty ? "Group \(row.group)" : "\(row.group)-\(row.letter)" }
              td { row.value.string() }
              td { row.quantity.string() }
              td { (row.value * Double(row.quantity)).string() }
            }
          }
          tr {
            td { "Straight duct" }
            td { path.straightLengths.map { $0.string() }.joined(separator: " + ") }
            td { "—" }
            td { path.straightLengths.reduce(0, +).string() }
          }
          tr(.class("total")) {
            td { "Path total" }
            td { "—" }
            td { "—" }
            td { path.totalEquivalentLength.string() }
          }
        }
      }
    }
  }
}
