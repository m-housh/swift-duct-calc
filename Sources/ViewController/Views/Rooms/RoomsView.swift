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
  let sensibleHeatRatio: Double?

  var body: some HTML {
    div {
      Row {
        h1(.class("text-2xl font-bold")) { "Room Loads" }
        div(
          .class("tooltip tooltip-left"),
          .data("tip", value: "Add room")
        ) {
          button(
            .showModal(id: RoomForm.id),
            .class("btn btn-primary w-[40px] text-2xl")
          ) {
            "+"
          }
        }
      }
      .attributes(.class("pb-6"))

      div(.class("border rounded-lg mb-6")) {
        Row {
          div(.class("space-x-6")) {
            Label("Sensible Heat Ratio")
            if let sensibleHeatRatio {
              Number(sensibleHeatRatio)
            }
          }

          EditButton()
            .attributes(.showModal(id: SHRForm.id))
        }
        .attributes(.class("m-4"))

        SHRForm(projectID: projectID, sensibleHeatRatio: sensibleHeatRatio)
      }

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
          Number(room.coolingTotal)
            .attributes(.class("text-success"))
        }
        // FIX: Add cooling sensible.
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

  struct SHRForm: HTML, Sendable {
    static let id = "shrForm"

    let projectID: Project.ID
    let sensibleHeatRatio: Double?

    var body: some HTML {
      ModalForm(id: Self.id, dismiss: true) {
        form(
          .class("space-y-6"),
          .hx.patch("/projects/\(projectID)/rooms/update-shr"),
          .hx.target("body"),
          .hx.swap(.outerHTML)
        ) {
          input(.class("hidden"), .name("projectID"), .value("\(projectID)"))
          div {
            label(.for("sensibleHeatRatio")) { "Sensible Heat Ratio" }
            Input(id: "sensibleHeatRatio", placeholder: "Sensible Heat Ratio")
              .attributes(.min("0"), .max("1"), .step("0.01"), .value(sensibleHeatRatio))
          }
          div {
            SubmitButton()
              .attributes(.class("btn-block"))
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
    reduce(into: 0) { $0 += $1.coolingTotal }
  }
}
