import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct RoomsView: HTML, Sendable {
  let rooms: [Room]

  var body: some HTML {
    div(.class("m-10")) {
      Row {
        h1(.class("text-3xl font-bold pb-6")) { "Room Loads" }
        // div(
        //   .class("tooltip"),
        //   .data("tip", value: "Add room")
        // ) {
        //   PlusButton()
        //     .attributes(
        //       .hx.get(route: .room(.form(dismiss: false))),
        //       .hx.target("#roomForm"),
        //       .hx.swap(.outerHTML),
        //       .class("btn")
        //     )
        // }
        HTMLRaw(
          """
          <div class="tooltip" data-tip="hello">
            <button class="btn">Hover me</button>
          </div>
          """
        )
      }

      div(
        .id("roomTable"),
        .class(
          """
          border border-gray-200 rounded-lg shadow-lg
          grid grid-cols-5 p-4
          """
        )
      ) {
        // Header
        Label("Name")
        // Pushes items to right
        Row {
          div {}
          Label("Heating Load")
        }
        Row {
          div {}
          Label("Cooling Total")
        }
        Row {
          div {}
          Label("Cooling Sensible")
        }
        Row {
          div {}
          Label("Register Count")
        }

        // Divider
        div(.class("border-b border-gray-200 col-span-5 mb-2")) {}

        // Rows
        for row in rooms {
          span { row.name }
          // Pushes items to right
          Row {
            div {}
            Number(row.heatingLoad)
              .attributes(.class("text-red-500"))
          }
          Row {
            div {}
            Number(row.coolingLoad.total)
              .attributes(.class("text-green-400"))
          }
          Row {
            div {}
            Number(row.coolingLoad.sensible)
              .attributes(.class("text-blue-400"))
          }
          Row {
            div {}
            Number(row.registerCount)
          }

          // Divider
          div(.class("border-b border-gray-200 col-span-5 mb-2")) {}
        }

        // Totals
        Label("Total")
        Row {
          div {}
          Number(rooms.heatingTotal)
            .attributes(.class("bg-red-500 text-white font-bold rounded-lg shadow-lg px-4 py-2"))
        }
        Row {
          div {}
          Number(rooms.coolingTotal)
            .attributes(.class("bg-green-400 text-white font-bold rounded-lg shadow-lg px-4 py-2"))
        }
        Row {
          div {}
          Number(rooms.coolingSensibleTotal)
            .attributes(.class("bg-blue-400 text-white font-bold rounded-lg shadow-lg px-4 py-2"))
        }
        // Empty register count column
        div {}
      }

      RoomForm(dismiss: true)
    }
  }

}

extension Array where Element == Room {
  var heatingTotal: Double {
    reduce(into: 0) { $0 += $1.heatingLoad }
  }

  var coolingTotal: Double {
    reduce(into: 0) { $0 += $1.coolingLoad.total }
  }

  var coolingSensibleTotal: Double {
    reduce(into: 0) { $0 += $1.coolingLoad.sensible }
  }
}
