import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Add error text if prior steps are not completed.

struct DuctSizingView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  // let projectID: Project.ID
  let rooms: [DuctSizing.RoomContainer]

  var body: some HTML {
    div {
      h1(.class("text-2xl py-4")) { "Duct Sizes" }
      if rooms.count == 0 {
        p(.class("text-error italic")) {
          "Must complete all the previous sections to display duct sizing calculations."
        }
      } else {
        RoomsTable(projectID: projectID, rooms: rooms)
      }
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
          Number(room.designCFM.value, digits: 0)
            .attributes(
              .class("badge badge-outline badge-\(room.designCFM.color) text-xl font-bold"))
        }
        td(.class("hidden 2xl:table-cell")) { Number(room.roundSize, digits: 0) }
        td { Number(room.velocity) }
        td {
          Number(room.finalSize)
            .attributes(.class("badge badge-outline badge-secondary text-xl  font-bold"))
        }
        td {
          Number(room.flexSize)
            .attributes(.class("badge badge-outline badge-primary text-xl  font-bold"))
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
}

extension DuctSizing.DesignCFM {
  var color: String {
    switch self {
    case .heating: return "error"
    case .cooling: return "info"
    }
  }
}
