import Elementary
import ManualDCore

struct RoomsTable: HTML, Sendable {
  let rooms: [Room]
  let projectSHR: Double

  var body: some HTML<HTMLTag.table> {
    table {
      thead {
        tr {
          ReportColumn("Room")
          ReportColumn("Heating", unit: "BTU/h")
          ReportColumn("Cooling total", unit: "BTU/h")
          ReportColumn("Cooling sensible", unit: "BTU/h")
          ReportColumn("Registers")
        }
      }
      tbody {
        for room in rooms {
          tr {
            td { room.name }
            td { room.heatingLoad.string(digits: 0) }
            td { try! room.coolingLoad.ensured(shr: projectSHR).total.string(digits: 0) }
            td {
              try! room.coolingLoad.ensured(shr: projectSHR).sensible.string(digits: 0)
            }
            td { room.registerCount.string() }
          }
        }
        tr(.class("total")) {
          td { "Totals" }
          td {
            rooms.totalHeatingLoad.string(digits: 0)
          }
          td {
            try! rooms.totalCoolingLoad(shr: projectSHR).string(digits: 0)
          }
          td {
            try! rooms.totalCoolingSensible(shr: projectSHR).string(digits: 0)
          }
          td { rooms.reduce(0) { $0 + $1.registerCount }.string() }
        }
      }
    }
  }
}
