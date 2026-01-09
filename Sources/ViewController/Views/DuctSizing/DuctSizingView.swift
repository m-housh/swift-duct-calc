import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Add error text if prior steps are not completed.

struct DuctSizingView: HTML, Sendable {

  let rooms: [DuctSizing.RoomContainer]

  var body: some HTML {
    div {
      h1(.class("text-2xl py-4")) { "Duct Sizes" }

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
              th(.class("hidden xl:table-cell")) { "Round Size" }
              th { "Velocity" }
              th { "Final Size" }
              th { "Flex Size" }
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
    let room: DuctSizing.RoomContainer

    var body: some HTML<HTMLTag.tr> {
      tr(.class("text-lg")) {
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
        td(.class("hidden xl:table-cell")) { Number(room.roundSize, digits: 0) }
        td { Number(room.velocity) }
        td {
          Number(room.finalSize)
            .attributes(.class("badge badge-outline badge-secondary text-xl  font-bold"))
        }
        td {
          Number(room.flexSize)
            .attributes(.class("badge badge-outline badge-primary text-xl  font-bold"))
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
