import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

extension DuctSizingView {

  struct RoomsTable: HTML, Sendable {
    @Environment(ProjectViewValue.$projectID) var projectID

    let rooms: [DuctSizing.RoomContainer]

    var body: some HTML<HTMLTag.div> {
      div(.class("overflow-x-auto")) {

        table(.class("table table-zebra")) {
          thead {
            tr(.class("text-xl text-gray-400 font-bold")) {
              th { "ID" }
              th { "Name" }
              th { "BTU" }
              th { "CFM" }
              th { "Velocity" }
              th { "Size" }
            }
          }
          tbody {
            for room in rooms {
              RoomRow(room: room)
            }
          }
        }
      }
    }
  }

  struct RoomRow: HTML, Sendable {

    static func id(_ room: DuctSizing.RoomContainer) -> String {
      "roomRow_\(room.registerID.idString)"
    }

    @Environment(ProjectViewValue.$projectID) var projectID

    let room: DuctSizing.RoomContainer
    let formID = UUID().idString

    var deleteRoute: String {
      guard let id = room.rectangularSize?.id else { return "" }

      return SiteRoute.View.router.path(
        for: .project(
          .detail(
            projectID,
            .ductSizing(
              .deleteRectangularSize(
                room.roomID,
                .init(rectangularSizeID: id, register: room.roomRegister)
              ))
          )
        )
      )
    }

    var rowID: String { Self.id(room) }

    var body: some HTML<HTMLTag.tr> {
      tr(.class("text-lg items-baseline"), .id(rowID)) {
        td { room.registerID }
        td { room.roomName }
        td {
          div(.class("grid grid-cols-2 gap-2")) {
            span(.class("label")) { "Heating" }
            Number(room.heatingLoad, digits: 0)

            span(.class("label")) { "Cooling" }
            Number(room.coolingLoad, digits: 0)
          }
        }

        td {
          div(.class("grid grid-cols-2 gap-2")) {

            span(.class("label")) { "Design" }
            div(.class("flex justify-center")) {
              Badge(number: room.designCFM.value, digits: 0)
            }

            span(.class("label")) { "Heating" }
            div(.class("flex justify-center")) {
              Number(room.heatingCFM, digits: 0)
            }

            span(.class("label")) { "Cooling" }
            div(.class("flex justify-center")) {
              Number(room.coolingCFM, digits: 0)
            }

          }
        }

        td { Number(room.velocity) }

        td {
          div(.class("grid grid-cols-3 gap-2")) {

            div(.class("label")) { "Calculated" }
            div(.class("flex justify-center")) {
              Badge(number: room.roundSize, digits: 1)
            }
            div {}

            div(.class("label")) { "Final" }
            div(.class("flex justify-center")) {
              Badge(number: room.finalSize)
                .attributes(.class("badge-secondary"))
            }
            div {}

            div(.class("label")) { "Flex" }
            div(.class("flex justify-center")) {
              Badge(number: room.flexSize)
                .attributes(.class("badge-primary"))
            }
            div {}

            div(.class("label")) { "Rectangular" }
            div(.class("flex justify-center")) {
              if let width = room.rectangularWidth,
                let height = room.rectangularSize?.height
              {
                Badge {
                  span { "\(width) x \(height)" }
                }
                .attributes(.class("badge-info"))
              }
            }
            div(.class("flex justify-end")) {
              div(.class("join")) {
                if room.rectangularSize != nil {
                  Tooltip("Delete Size", position: .bottom) {
                    TrashButton()
                      .attributes(.class("join-item btn-ghost"))
                      .attributes(
                        .hx.delete(deleteRoute),
                        .hx.target("#\(rowID)"),
                        .hx.swap(.outerHTML),
                        when: room.rectangularSize != nil
                      )
                  }
                }

                Tooltip("Edit Size", position: .bottom) {
                  EditButton()
                    .attributes(
                      .class("join-item btn-ghost"),
                      .showModal(id: RectangularSizeForm.id(room))
                    )
                }

              }
            }
            RectangularSizeForm(room: room)
          }
        }
      }
    }
  }

}
