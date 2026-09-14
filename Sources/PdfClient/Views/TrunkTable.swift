import Elementary
import ManualDCore

struct TrunkTable: HTML, Sendable {
  let sizes: DuctSizes

  var body: some HTML<HTMLTag.table> {
    table(.class("duct-sizes")) {
      thead {
        tr {
          ReportColumn("Duct")
          DuctSizeColumns()
        }
      }
      tbody {
        for row in sizes.trunks {
          tr {
            td {
              if let name = row.name, !name.isEmpty {
                "\(row.type.rawValue.capitalized) · \(name)"
              } else {
                "\(row.type.rawValue.capitalized) trunk"
              }
            }
            DuctSizeCells(size: row.ductSize)
          }
        }
        if sizes.trunks.isEmpty {
          tr { td(.custom(name: "colspan", value: "8")) { "No trunks or runouts." } }
        }
      }
    }
  }
}
