import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

// TODO: Calculate rooms sensible based on project wide SHR.

struct RoomsView: HTML, Sendable {
  let projectID: Project.ID
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
            .hx.get(route: .project(.detail(projectID, .rooms(.form(dismiss: false))))),
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
              th { Label("Register Count") }
              th {}
            }
          }
          tbody {
            div(.id("rooms")) {
              for room in rooms {
                RoomRow(room: room)
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
              td {}
              td {}
            }
          }
        }
      }
      RoomForm(dismiss: true, projectID: projectID, room: nil)
    }
  }

  public struct RoomRow: HTML, Sendable {
    let room: Room

    public var body: some HTML {
      tr(.id("\(room.id)")) {
        td { room.name }
        td {
          Number(room.heatingLoad)
            .attributes(.class("text-error"))
        }
        td {
          Number(room.coolingLoad)
            .attributes(.class("text-success"))
        }
        td {
          Number(room.registerCount)
        }
        td {
          div(.class("flex justify-end space-x-6")) {
            TrashButton()
              .attributes(
                .hx.delete(
                  route: .project(.detail(room.projectID, .rooms(.delete(id: room.id))))),
                .hx.target("closest tr"),
                .hx.confirm("Are you sure?")
              )
            EditButton()
              .attributes(
                .hx.get(
                  route: .project(
                    .detail(room.projectID, .rooms(.form(id: room.id, dismiss: false)))
                  )
                ),
                .hx.target("#roomForm"),
                .hx.swap(.outerHTML)
              )
          }
        }
      }
    }
  }

}

extension Array where Element == Room {
  var heatingTotal: Double {
    reduce(into: 0) { $0 += $1.heatingLoad }
  }

  var coolingTotal: Double {
    reduce(into: 0) { $0 += $1.coolingLoad }
  }
}
