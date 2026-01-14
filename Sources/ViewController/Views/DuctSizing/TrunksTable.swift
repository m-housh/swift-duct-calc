import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

extension DuctSizingView {

  struct TrunkTable: HTML, Sendable {

    let trunks: [DuctSizing.TrunkContainer]
    let rooms: [DuctSizing.RoomContainer]

    private var sortedTrunks: [DuctSizing.TrunkContainer] {
      trunks.sorted(by: { $0.type.rawValue > $1.type.rawValue })
    }

    var body: some HTML {
      table(.class("table table-zebra text-lg")) {
        thead {
          tr(.class("text-lg")) {
            th { "Type" }
            th { "Associated Supplies" }
            th { "Dsn CFM" }
            th { "Velocity" }
            th { "Size" }
          }
        }
        tbody {
          for trunk in sortedTrunks {
            TrunkRow(trunk: trunk, rooms: rooms)
          }
        }
      }
    }

  }

  struct TrunkRow: HTML, Sendable {

    @Environment(ProjectViewValue.$projectID) var projectID

    let trunk: DuctSizing.TrunkContainer
    let rooms: [DuctSizing.RoomContainer]

    var body: some HTML<HTMLTag.tr> {
      tr {
        td {
          Badge {
            trunk.trunk.type.rawValue
          }
          .attributes(.class("badge-info"), when: trunk.type == .supply)
          .attributes(.class("badge-error"), when: trunk.type == .return)
        }
        td(.class("space-x-2")) {
          for id in registerIDS {
            Badge { id }
          }
        }
        td {
          Number(trunk.designCFM.value, digits: 0)
        }
        td {
          Number(trunk.velocity)
        }
        td {
          div(.class("grid grid-cols-3 gap-4")) {
            div(.class("label")) { "Calculated" }
            div(.class("flex justify-center")) {
              Badge(number: trunk.roundSize, digits: 1)
            }
            div {}

            div(.class("label")) { "Final" }
            div(.class("flex justify-center")) {
              Badge(number: trunk.finalSize)
                .attributes(.class("badge-secondary"))
            }
            div {}

            div(.class("label")) { "Flex" }
            div(.class("flex justify-center")) {
              Badge(number: trunk.flexSize)
                .attributes(.class("badge-primary"))
            }
            div {}

            div(.class("label")) { "Rectangular" }
            div(.class("flex justify-center")) {
              if let width = trunk.width,
                let height = trunk.ductSize.height
              {
                Badge {
                  span { "\(width) x \(height)" }
                }
              }
            }
            div(.class("flex justify-end")) {
              div(.class("join")) {
                TrashButton()
                  .attributes(.class("join-item btn-ghost"))
                  .attributes(
                    .hx.delete(route: deleteRoute),
                    .hx.target("closest tr"),
                    .hx.swap(.outerHTML)
                  )

                EditButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .showModal(id: TrunkSizeForm.id(trunk))
                  )
              }
            }
          }
          TrunkSizeForm(trunk: trunk, rooms: rooms, dismiss: true)
        }
      }
    }

    private var deleteRoute: SiteRoute.View {
      .project(.detail(projectID, .ductSizing(.trunk(.delete(trunk.id)))))
    }

    private var registerIDS: [String] {
      trunk.rooms.reduce(into: []) { array, room in
        array = room.registers.reduce(into: array) { array, register in
          if let room =
            rooms
            .first(where: { $0.roomID == room.id && $0.roomRegister == register })
          {
            array.append(room.registerID)
          }
        }
      }
      .sorted()
    }

  }
}
