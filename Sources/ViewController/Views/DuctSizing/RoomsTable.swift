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
              th(.class("hidden 2xl:table-cell")) { "Round Size" }
              th { "Velocity" }
              th { "Size" }
              th {}
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

    @Environment(ProjectViewValue.$projectID) var projectID

    let room: DuctSizing.RoomContainer
    let formID = UUID().idString

    var deleteRoute: String {
      guard let id = room.rectangularSize?.id else { return "" }

      return SiteRoute.View.router.path(
        for: .project(
          .detail(
            projectID,
            .ductSizing(.deleteRectangularSize(room.roomID, id))
          )
        )
      )
    }

    var body: some HTML<HTMLTag.tr> {
      tr(.class("text-lg items-baseline"), .id(room.roomID.idString)) {
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
            Badge(number: room.designCFM.value, digits: 0)

            span(.class("label")) { "Heating" }
            Number(room.heatingCFM, digits: 0)

            span(.class("label")) { "Cooling" }
            Number(room.coolingCFM, digits: 0)

          }
        }

        td(.class("hidden 2xl:table-cell")) { Number(room.roundSize, digits: 1) }
        td { Number(room.velocity) }

        td {
          div(.class("grid grid-cols-2 gap-2")) {

            span(.class("label")) { "Final" }
            Badge(number: room.finalSize)
              .attributes(.class("badge-secondary"))

            span(.class("label")) { "Flex" }
            Badge(number: room.flexSize)
              .attributes(.class("badge-primary"))

            if let width = room.rectangularWidth,
              let height = room.rectangularSize?.height
            {
              span(.class("label")) { "Rectangular" }
              Badge {
                span { "\(width) x \(height)" }
              }
            }
          }
        }

        td {
          div(.class("flex justify-end space-x-4")) {
            div(.class("join")) {
              if room.rectangularSize != nil {
                // FIX: Delete rectangular size from room.
                TrashButton()
                  .attributes(.class("join-item btn-ghost"))
                  .attributes(
                    .hx.delete(deleteRoute),
                    .hx.target("closest tr"),
                    .hx.swap(.outerHTML),
                    when: room.rectangularSize != nil
                  )
              }

              EditButton()
                .attributes(
                  .class("join-item btn-ghost"),
                  .showModal(id: formID)
                  // .showModal(id: RectangularSizeForm.id(room))
                )

            }
          }

          // FakeForm(id: formID)
          RectangularSizeForm(id: formID, room: room)
          // .attributes(.class("modal-open"))

        }
      }
    }
  }

  struct FakeForm: HTML, Sendable {
    let id: String

    var body: some HTML<HTMLTag.dialog> {
      ModalForm(id: id, dismiss: true) {
        div { "Fake Form" }
      }
    }
  }

}
