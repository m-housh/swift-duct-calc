import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct RoomsView: HTML, Sendable {
  let rooms: [Room]

  var body: some HTML {
    div {
      Row {
        h1(.class("text-2xl font-bold")) { "Room Loads" }
        div(
          .class("tooltip tooltip-left"),
          .data("tip", value: "Add room")
        ) {
          button(
            .hx.get(route: .room(.form(dismiss: false))),
            .hx.target("#roomForm"),
            .hx.swap(.outerHTML),
            .class("btn btn-primary w-[40px] text-2xl")
          ) {
            "+"
          }
        }
      }
      .attributes(.class("pb-6"))

      div(.class("overflow-x-auto rounded-box border")) {
        table(.class("table table-zebra"), .id("roomsTable")) {
          thead {
            tr {
              th { Label("Name") }
              th { Label("Heating Load") }
              th { Label("Cooling Total") }
              th { Label("Cooling Sensible") }
              th { Label("Register Count") }
            }
          }
          tbody {
            for room in rooms {
              tr {
                td { room.name }
                td {
                  Number(room.heatingLoad)
                    .attributes(.class("text-error"))
                }
                td {
                  Number(room.coolingLoad.total)
                    .attributes(.class("text-success"))
                }
                td {
                  Number(room.coolingLoad.sensible)
                    .attributes(.class("text-info"))
                }
                td {
                  Number(room.registerCount)
                }
              }
            }
            // TOTALS
            tr(.class("font-bold text-xl")) {
              td { Label("Total") }
              td {
                Number(rooms.heatingTotal)
                  .attributes(.class("badge badge-outline badge-error badge-xl"))
              }
              td {
                Number(rooms.coolingTotal)
                  .attributes(
                    .class("badge badge-outline badge-success badge-xl"))
              }
              td {
                Number(rooms.coolingSensibleTotal)
                  .attributes(.class("badge badge-outline badge-info badge-xl"))
              }
              td {}
            }
          }
        }
      }
      RoomForm(dismiss: true)
    }
  }

}

extension Array where Element == Room {
  var heatingTotal: Double {
    reduce(into: 0) { $0 += $1.heatingLoad }
  }

  var coolingTotal: Double {
    reduce(into: 0) { $0 += $1.coolingLoad.total }
  }

  var coolingSensibleTotal: Double {
    reduce(into: 0) { $0 += $1.coolingLoad.sensible }
  }
}
