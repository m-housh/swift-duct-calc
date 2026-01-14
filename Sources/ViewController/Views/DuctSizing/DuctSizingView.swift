import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Add trunk size table.

struct DuctSizingView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let rooms: [DuctSizing.RoomContainer]
  let trunks: [DuctSizing.TrunkContainer]

  var supplyTrunks: [DuctSizing.TrunkContainer] {
    trunks.filter { $0.trunk.type == .supply }
  }

  var returnTrunks: [DuctSizing.TrunkContainer] {
    trunks.filter { $0.trunk.type == .return }
  }

  var body: some HTML {
    div(.class("space-y-4")) {
      PageTitle { "Duct Sizes" }
      if rooms.count == 0 {
        p(.class("text-error italic")) {
          "Must complete all the previous sections to display duct sizing calculations."
        }
      } else {
        RoomsTable(rooms: rooms)
      }

      // Row {
      //   h2(.class("text-2xl font-bold")) { "Trunk Sizes" }
      //
      //   PlusButton()
      //     .attributes(
      //       .class("me-6"),
      //       .showModal(id: TrunkSizeForm.id())
      //     )
      // }
      // .attributes(.class("mt-6"))
      //
      // div(.class("divider -mt-2")) {}
      //
      // if supplyTrunks.count > 0 {
      //   h2(.class("text-lg font-bold text-info")) { "Supply Trunks" }
      //   TrunkTable(trunks: supplyTrunks, rooms: rooms)
      // }
      //
      // if returnTrunks.count > 0 {
      //   h2(.class("text-lg font-bold text-error")) { "Return Trunks" }
      //   TrunkTable(trunks: returnTrunks, rooms: rooms)
      // }
      //
      // TrunkSizeForm(rooms: rooms, dismiss: true)
    }
  }

  struct TrunkTable: HTML, Sendable {

    let trunks: [DuctSizing.TrunkContainer]
    let rooms: [DuctSizing.RoomContainer]

    var body: some HTML {
      div(.class("overflow-x-auto")) {
        table(.class("table table-zebra text-lg")) {
          thead {
            tr(.class("text-lg")) {
              th { "Associated Supplies" }
              th { "Dsn CFM" }
              th { "Round Size" }
              th { "Velocity" }
              th { "Final Size" }
              th { "Flex Size" }
              th { "Width" }
              th { "Height" }
            }
          }
          tbody {
            for trunk in trunks {
              TrunkRow(trunk: trunk, rooms: rooms)
            }
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
        td(.class("space-x-2")) {
          for id in registerIDS(trunk.trunk) {
            Badge { id }
          }
        }
        td {
          Number(trunk.ductSize.designCFM.value, digits: 0)
        }
        td {
          Number(trunk.ductSize.roundSize, digits: 1)
        }
        td {
          Number(trunk.ductSize.velocity)
        }
        td {
          Badge(number: trunk.ductSize.finalSize)
            .attributes(.class("badge-secondary"))
        }
        td {
          Badge(number: trunk.ductSize.flexSize)
            .attributes(.class("badge-primary"))
        }
        td {
          if let width = trunk.ductSize.width {
            Number(width)
          }

        }
        td {

          div(.class("flex justify-between items-center space-x-4")) {
            div {
              if let height = trunk.ductSize.height {
                Number(height)
              }
            }

            div {
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

    private func registerIDS(_ trunk: DuctSizing.TrunkSize) -> [String] {
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

extension DuctSizing.DesignCFM {
  var color: String {
    switch self {
    case .heating: return "error"
    case .cooling: return "info"
    }
  }
}
