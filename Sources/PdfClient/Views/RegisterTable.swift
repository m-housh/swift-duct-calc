import Elementary
import ManualDCore

struct RegisterDetailTable: HTML, Sendable {
  let rooms: [DuctSizes.RoomContainer]

  var body: some HTML<HTMLTag.table> {
    table {
      thead {
        tr(.class("bg-green")) {
          th { "Name" }
          th { "Heating BTU" }
          th { "Cooling BTU" }
          th { "Heating CFM" }
          th { "Cooling CFM" }
          th { "Design CFM" }
        }
      }
      tbody {
        for row in rooms {
          tr {
            td { row.roomName }
            td { row.heatingLoad.string(digits: 0) }
            td { row.coolingLoad.string(digits: 0) }
            td { row.heatingCFM.string(digits: 0) }
            td { row.coolingCFM.string(digits: 0) }
            td { row.designCFM.value.string(digits: 0) }
          }
        }
      }
    }
  }
}
