import Elementary
import ManualDCore

struct RoomsTable: HTML, Sendable {
  let rooms: [Room]
  let projectSHR: Double

  var body: some HTML<HTMLTag.table> {
    table {
      thead {
        tr(.class("bg-green")) {
          th { "Name" }
          th { "Heating BTU" }
          th { "Cooling Total BTU" }
          th { "Cooling Sensible BTU" }
          th { "Register Count" }
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
        // Totals
        // tr(.class("table-footer")) {
        tr {
          td(.class("label")) { "Totals" }
          td(.class("heating label")) {
            rooms.totalHeatingLoad.string(digits: 0)
          }
          td(.class("coolingTotal label")) {
            try! rooms.totalCoolingLoad(shr: projectSHR).string(digits: 0)
          }
          td(.class("coolingSensible label")) {
            try! rooms.totalCoolingSensible(shr: projectSHR).string(digits: 0)
          }
          td {}
        }
      }
    }
  }
}
