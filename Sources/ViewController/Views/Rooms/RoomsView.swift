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
        PageTitle { "Room Loads" }

        div(.class("flex justify-end items-end -my-2")) {
          Tooltip("Project wide sensible heat ratio", position: .left) {
            button(
              .class(
                """
                justify-end items-end p-4
                hover:bg-neutral hover:text-white hover:rounded-lg
                """
              ),
              .showModal(id: SHRForm.id)
            ) {
              LabeledContent {
                div(.class("flex justify-end items-end space-x-4")) {
                  Label {
                    "Sensible Heat Ratio"
                  }
                  .attributes(.class("me-8"), when: sensibleHeatRatio == nil)
                }
              } content: {
                if let sensibleHeatRatio {
                  Badge(number: sensibleHeatRatio)
                } else {
                  SVG(.squarePen)
                }
              }
            }
            .attributes(.class("border rounded-lg border-error"), when: sensibleHeatRatio == nil)
          }
        }
      }

      div(.class("flex flex-wrap justify-between mt-6")) {
        div(.class("flex items-end space-x-4")) {
          Label { "Heating Total" }
          Badge(number: rooms.heatingTotal, digits: 0)
            .attributes(.class("badge-error"))
        }

        div(.class("flex items-end space-x-4")) {
          Label { "Cooling Total" }
          Badge(number: rooms.coolingTotal, digits: 0)
            .attributes(.class("badge-success"))
        }

        div(.class("flex justify-end items-end space-x-4 me-4")) {
          Label { "Cooling Sensible" }
          Badge(number: rooms.coolingSensible(shr: sensibleHeatRatio), digits: 0)
            .attributes(.class("badge-info"))
        }
      }
      // .attributes(.class("mt-6 me-4"))

      div(.class("divider")) {}

      SHRForm(projectID: projectID, sensibleHeatRatio: sensibleHeatRatio)

      div(.class("overflow-x-auto")) {
        table(.class("table table-zebra text-lg"), .id("roomsTable")) {
          thead {
            tr(.class("text-lg font-bold")) {
              th { "Name" }
              th {
                div(.class("flex justify-center")) {
                  "Heating Load"
                }
              }
              th {
                div(.class("flex justify-center")) {
                  "Cooling Total"
                }
              }
              th {
                div(.class("flex justify-center")) {
                  "Cooling Sensible"
                }
              }
              th {
                div(.class("flex justify-center")) {
                  "Register Count"
                }
              }
              th {
                div(.class("flex justify-end me-2")) {
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
      tr(.id("roomRow_\(room.id.idString)")) {
        td { room.name }
        td {
          div(.class("flex justify-center")) {
            Number(room.heatingLoad, digits: 0)
            // .attributes(.class("text-error"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(room.coolingTotal, digits: 0)
            // .attributes(.class("text-success"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(coolingSensible, digits: 0)
            // .attributes(.class("text-info"))
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

    var route: String {
      SiteRoute.View.router
        .path(for: .project(.detail(projectID, .rooms(.index))))
        .appendingPath("update-shr")
    }

    var body: some HTML {
      ModalForm(id: Self.id, dismiss: true) {
        h1(.class("text-xl font-bold mb-6")) {
          "Sensible Heat Ratio"
        }
        form(
          .class("grid grid-cols-1 gap-4"),
          .hx.patch(route),
          .hx.target("body"),
          .hx.swap(.outerHTML)
        ) {
          input(.class("hidden"), .name("projectID"), .value("\(projectID)"))
          LabeledInput(
            "SHR",
            .name("sensibleHeatRatio"),
            .type(.number),
            .value(sensibleHeatRatio),
            .placeholder("0.83"),
            .min("0"),
            .max("1"),
            .step("0.01"),
            .autofocus
          )
          SubmitButton()
            .attributes(.class("btn-block my-6"))
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
