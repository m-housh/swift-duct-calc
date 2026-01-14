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
        RoomsTable(projectID: projectID, rooms: rooms)
      }

      Row {
        h2(.class("text-2xl font-bold")) { "Trunk Sizes" }

        PlusButton()
          .attributes(
            .class("me-6"),
            .showModal(id: TrunkSizeForm.id())
          )
      }
      .attributes(.class("mt-6"))

      div(.class("divider -mt-2")) {}

      if supplyTrunks.count > 0 {
        h2(.class("text-lg font-bold text-info")) { "Supply Trunks" }
        TrunkTable(trunks: supplyTrunks, rooms: rooms)
      }

      if returnTrunks.count > 0 {
        h2(.class("text-lg font-bold text-error")) { "Return Trunks" }
        TrunkTable(trunks: returnTrunks, rooms: rooms)
      }

      TrunkSizeForm(rooms: rooms, dismiss: true)
    }
  }

  struct RoomsTable: HTML, Sendable {
    let projectID: Project.ID
    let rooms: [DuctSizing.RoomContainer]

    var body: some HTML<HTMLTag.div> {
      div(.class("overflow-x-auto")) {
        table(.class("table table-zebra")) {
          thead {
            tr(.class("text-xl text-gray-400 font-bold")) {
              th { "ID" }
              th { "Name" }
              th { "H-BTU" }
              th { "C-BTU" }
              th(.class("hidden 2xl:table-cell")) { "Htg CFM" }
              th(.class("hidden 2xl:table-cell")) { "Clg CFM" }
              th { "Dsn CFM" }
              th(.class("hidden 2xl:table-cell")) { "Round Size" }
              th { "Velocity" }
              th { "Final Size" }
              th { "Flex Size" }
              th { "Width" }
              th { "Height" }
            }
          }
          tbody {
            for room in rooms {
              RoomRow(projectID: projectID, room: room)
            }
          }
        }
      }
    }
  }

  struct RoomRow: HTML, Sendable {
    let projectID: Project.ID
    let room: DuctSizing.RoomContainer

    var route: String {
      SiteRoute.View.router.path(
        for: .project(.detail(projectID, .ductSizing(.index)))
      )
      .appendingPath("room")
      .appendingPath(room.roomID)
    }

    var body: some HTML<HTMLTag.tr> {
      tr(.class("text-lg items-baseline"), .id(room.roomID.idString)) {
        td { room.registerID }
        td { room.roomName }
        td { Number(room.heatingLoad, digits: 0) }
        td { Number(room.coolingLoad, digits: 0) }
        td(.class("hidden 2xl:table-cell")) { Number(room.heatingCFM, digits: 0) }
        td(.class("hidden 2xl:table-cell")) { Number(room.coolingCFM, digits: 0) }
        td {
          Badge(number: room.designCFM.value, digits: 0)
            .attributes(.class("badge-\(room.designCFM.color)"))
        }
        td(.class("hidden 2xl:table-cell")) { Number(room.roundSize, digits: 1) }
        td { Number(room.velocity) }
        td {
          Badge(number: room.finalSize)
            .attributes(.class("badge-secondary"))
        }
        td {
          Badge(number: room.flexSize)
            .attributes(.class("badge-primary"))
        }
        td {
          if let width = room.rectangularWidth {
            Number(width)
          }
        }
        td {
          div(.class("flex justify-between items-center space-x-4")) {
            div(.id("height_\(room.roomID.idString)"), .class("h-full my-auto")) {
              if let height = room.rectangularSize?.height {
                Number(height)
              }
            }
            div {
              div(.class("join")) {
                // FIX: Delete rectangular size from room.
                TrashButton()
                  .attributes(.class("join-item btn-ghost"))
                  .attributes(
                    .hx.delete(
                      route: .project(
                        .detail(
                          projectID,
                          .ductSizing(
                            .deleteRectangularSize(
                              room.roomID,
                              room.rectangularSize?.id ?? .init())
                          )
                        )
                      )
                    ),
                    .hx.target("closest tr"),
                    .hx.swap(.outerHTML),
                    when: room.rectangularSize != nil
                  )

                EditButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .showModal(id: RectangularSizeForm.id(room))
                  )
              }
            }
          }
          RectangularSizeForm(projectID: projectID, room: room)
        }
      }
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
