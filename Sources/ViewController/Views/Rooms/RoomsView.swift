import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct RoomsView: HTML, Sendable {
  @Environment(ProjectViewValue.$projectID) var projectID
  // let projectID: Project.ID
  let rooms: [Room]
  let sensibleHeatRatio: Double?

  var body: some HTML {
    div(.class("flex w-full flex-col")) {
      Row {
        h1(
          .class("flex flex-row text-2xl font-bold pb-6 h-full items-center")
        ) { "Room Loads" }

        div(.class("flex justify-end")) {
          Tooltip("Project wide sensible heat ratio", position: .left) {
            button(
              .class(
                """
                grid grid-cols-1 gap-2 p-4 justify-end
                hover:bg-neutral hover:text-white hover:rounded-lg
                """
              ),
              .showModal(id: SHRForm.id)
            ) {
              LabeledContent("Sensible Heat Ratio") {
                if let sensibleHeatRatio {
                  Badge(number: sensibleHeatRatio)
                }
              }
              div(.class("flex justify-end")) {
                SVG(.squarePen)
              }
            }
          }
        }
      }

      div(.class("divider")) {}

      SHRForm(projectID: projectID, sensibleHeatRatio: sensibleHeatRatio)

      div(.class("overflow-x-auto")) {
        table(.class("table table-zebra"), .id("roomsTable")) {
          thead {
            tr {
              th { Label("Name") }
              th {
                div(.class("flex justify-center")) {
                  Label("Heating Load")
                }
              }
              th {
                div(.class("flex justify-center")) {
                  Label("Cooling Total")
                }
              }
              th {
                div(.class("flex justify-center")) {
                  Label("Cooling Sensible")
                }
              }
              th {
                div(.class("flex justify-center")) {
                  Label("Register Count")
                }
              }
              th {
                div(.class("flex justify-end")) {
                  Tooltip("Add Room") {
                    PlusButton()
                      .attributes(
                        .class("btn-ghost mx-auto"),
                        .showModal(id: RoomForm.id())
                      )
                      .attributes(.class("tooltip-left"))
                  }
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
                div(.class("flex justify-center")) {
                  Badge(number: rooms.heatingTotal)
                    .attributes(.class("badge-error badge-xl"))
                }
              }
              td {
                div(.class("flex justify-center")) {
                  Badge(number: rooms.coolingTotal, digits: 0)
                    .attributes(.class("badge-success badge-xl"))
                }
              }
              td {
                div(.class("flex justify-center")) {
                  Badge(number: rooms.coolingSensible(shr: sensibleHeatRatio), digits: 0)
                    .attributes(.class("badge-info badge-xl"))
                }
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
          div(.class("flex justify-center")) {
            Number(room.heatingLoad, digits: 0)
              .attributes(.class("text-error"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(room.coolingTotal, digits: 0)
              .attributes(.class("text-success"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(coolingSensible, digits: 0)
              .attributes(.class("text-info"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(room.registerCount)
          }
        }
        td {
          div(.class("flex justify-end")) {
            div(.class("join")) {
              Tooltip("Delete room", position: .bottom) {
                TrashButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .hx.delete(
                      route: .project(.detail(room.projectID, .rooms(.delete(id: room.id))))),
                    .hx.target("closest tr"),
                    .hx.confirm("Are you sure?")
                  )
              }

              Tooltip("Edit room", position: .bottom) {
                EditButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .showModal(id: RoomForm.id(room))
                  )
              }
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
