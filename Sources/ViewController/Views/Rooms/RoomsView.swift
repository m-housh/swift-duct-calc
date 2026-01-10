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
        // div(
        //   .class("tooltip tooltip-left"),
        //   .data("tip", value: "Add room")
        // ) {
        //   div(.class("flex me-4")) {
        //     PlusButton()
        //       .attributes(.showModal(id: RoomForm.id()))
        //   }
        // }
      }
      .attributes(.class("pb-6"))

      div(.class("border rounded-lg mb-6")) {
        Row {
          div(.class("space-x-6 my-2")) {
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
              th { Label("Cooling Sensible") }
              th { Label("Register Count") }
              th {
                div(.class("flex justify-end")) {
                  Tooltip("Add Room") {
                    PlusButton()
                      .attributes(
                        .class("mx-auto"),
                        .showModal(id: RoomForm.id())
                      )
                  }
                  .attributes(.class("tooltip-left"))
                }
              }
            }
          }
          tbody {
            for room in rooms {
              RoomRow(room: room, shr: sensibleHeatRatio)
            }
            // TOTALS
            tr(.class("font-bold text-xl")) {
              td { Label("Total") }
              td {
                Number(rooms.heatingTotal, digits: 0)
                  .attributes(.class("badge badge-outline badge-error badge-xl"))
              }
              td {
                Number(rooms.coolingTotal, digits: 0)
                  .attributes(.class("badge badge-outline badge-success badge-xl"))
              }
              td {
                Number(rooms.coolingSensible(shr: sensibleHeatRatio), digits: 0)
                  .attributes(.class("badge badge-outline badge-info badge-xl"))
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
    let shr: Double

    var coolingSensible: Double {
      guard let value = room.coolingSensible else {
        return room.coolingTotal * shr
      }
      return value
    }

    init(room: Room, shr: Double?) {
      self.room = room
      self.shr = shr ?? 1.0
    }

    public var body: some HTML {
      tr(.id("roomRow_\(room.name)")) {
        td { room.name }
        td {
          Number(room.heatingLoad, digits: 0)
            .attributes(.class("text-error"))
        }
        td {
          Number(room.coolingTotal, digits: 0)
            .attributes(.class("text-success"))
        }
        td {
          Number(coolingSensible, digits: 0)
            .attributes(.class("text-info"))
        }
        td {
          Number(room.registerCount)
        }
        td {
          div(.class("flex justify-end")) {
            div(.class("join")) {
              Tooltip("Delete room") {
                TrashButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .hx.delete(
                      route: .project(.detail(room.projectID, .rooms(.delete(id: room.id))))),
                    .hx.target("closest tr"),
                    .hx.confirm("Are you sure?")
                  )
              }
              .attributes(.class("tooltip-bottom"))

              Tooltip("Edit room") {
                EditButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .showModal(id: RoomForm.id(room))
                  )
              }
              .attributes(.class("tooltip-bottom"))
            }
          }
          RoomForm(
            dismiss: true,
            projectID: room.projectID,
            room: room
          )
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

  func coolingSensible(shr: Double?) -> Double {
    let shr = shr ?? 1.0

    return reduce(into: 0) {
      let sensible = $1.coolingSensible ?? ($1.coolingTotal * shr)
      $0 += sensible
    }
  }
}
