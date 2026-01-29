import Elementary
import ManualDCore

struct TrunkTable: HTML, Sendable {
  public let sizes: DuctSizes
  public let type: TrunkSize.TrunkType

  var trunks: [DuctSizes.TrunkContainer] {
    sizes.trunks.filter { $0.type == type }
  }

  var body: some HTML<HTMLTag.table> {
    table {
      thead(.class("bg-green")) {
        tr {
          th { "Name" }
          th { "Dsn CFM" }
          th { "Round Size" }
          th { "Velocity" }
          th { "Final Size" }
          th { "Flex Size" }
          th { "Height" }
          th { "Width" }
        }
      }
      tbody {
        for row in trunks {
          tr {
            td { row.name ?? "" }
            td { row.designCFM.value.string(digits: 0) }
            td { row.ductSize.roundSize.string() }
            td { row.velocity.string() }
            td { row.finalSize.string() }
            td { row.flexSize.string() }
            td { row.ductSize.height?.string() ?? "" }
            td { row.width?.string() ?? "" }
          }
        }
      }
    }
  }
}
