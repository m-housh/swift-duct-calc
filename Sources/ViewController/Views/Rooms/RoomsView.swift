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
        h1(.class("text-3xl font-bold pb-6")) { "Rooms" }
        button(
          .hx.get(route: .room(.form(dismiss: false))),
          .hx.target("#roomForm"),
          .hx.swap(.outerHTML)
        ) {
          Icon(.circlePlus)
        }
      }

      div(
        .id("roomTable"),
        .class(
          """
          border border-gray-200 rounded-lg shadow-lg
          space-y-4 p-4
          """
        )
      ) {
        // Header
        Row {
          Label("Name")
          Label("Heating Load")
          Label("Cooling Total")
          Label("Cooling Sensible")
          Label("Register Count")
        }
        .attributes(.class("border-b border-gray-200"))

        // Rows
        for row in rooms {
          Row {
            span { row.name }
            Number(row.heatingLoad)
              .attributes(.class("text-red-500"))
            Number(row.coolingLoad.total)
              .attributes(.class("text-green-400"))
            Number(row.coolingLoad.sensible)
              .attributes(.class("text-blue-400"))
            Number(row.registerCount)
          }
          .attributes(.class("border-b border-gray-200"))
        }

      }

      div(.id("roomForm")) {}
    }
  }

}
