import Elementary
import ManualDCore

struct DuctSizesTable: HTML, Sendable {
  let rooms: [DuctSizes.RoomContainer]

  var body: some HTML<HTMLTag.table> {
    table {
      thead {
        tr(.class("bg-green")) {
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
        for row in rooms {
          tr {
            td { row.roomName }
            td { row.designCFM.value.string(digits: 0) }
            td { row.roundSize.string() }
            td { row.velocity.string() }
            td { row.flexSize.string() }
            td { row.finalSize.string() }
            td { row.ductSize.height?.string() ?? "" }
            td { row.width?.string() ?? "" }
          }
        }
      }
    }
  }
}
