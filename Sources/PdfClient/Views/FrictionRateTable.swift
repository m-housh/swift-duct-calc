import Elementary
import ManualDCore

struct FrictionRateTable: HTML, Sendable {
  let title: String?
  let componentLosses: [ComponentPressureLoss]
  let frictionRate: FrictionRate
  let totalEquivalentLength: Double
  let displayTotals: Bool

  var sortedLosses: [ComponentPressureLoss] {
    componentLosses.sorted { $0.value > $1.value }
  }

  var body: some HTML<HTMLTag.table> {
    table {
      thead {
        tr(.class("bg-green")) {
          th { title ?? "" }
          th(.class("justify-end")) { "Value" }
        }
      }
      tbody {
        for row in sortedLosses {
          tr {
            td { row.name }
            td(.class("justify-end")) { row.value.string() }
          }
        }
        if displayTotals {
          tr {
            td(.class("label justify-end")) { "Available Static Pressure" }
            td(.class("justify-end")) { frictionRate.availableStaticPressure.string() }
          }
          tr {
            td(.class("label justify-end")) { "Total Equivalent Length" }
            td(.class("justify-end")) { totalEquivalentLength.string() }
          }
          tr {
            td(.class("label justify-end")) { "Friction Rate Design Value" }
            td(.class("justify-end")) { frictionRate.value.string() }
          }
        }
      }
    }
  }
}
