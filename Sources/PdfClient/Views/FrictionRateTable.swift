import Elementary
import ManualDCore

struct FrictionRateTable: HTML, Sendable {
  let componentLosses: [ComponentPressureLoss]

  var sortedLosses: [ComponentPressureLoss] {
    componentLosses.sorted { $0.value == $1.value ? $0.name < $1.name : $0.value > $1.value }
  }

  var body: some HTML<HTMLTag.table> {
    table(.class("loss-table")) {
      thead {
        tr {
          ReportColumn("Component")
          ReportColumn("in. w.c.")
        }
      }
      tbody {
        for row in sortedLosses {
          tr {
            td { row.name }
            td { row.value.string() }
          }
        }
        tr(.class("total")) {
          td { "Total losses" }
          td { componentLosses.reduce(0) { $0 + $1.value }.string() }
        }
      }
    }
  }
}
