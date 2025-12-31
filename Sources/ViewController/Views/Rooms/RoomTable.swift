import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct RoomTable: HTML, Sendable {
  let rooms: [Room]

  var body: some HTML {
    div(.class("m-10")) {
      h1(.class("text-3xl font-bold")) { "Rooms" }
      table(
        .id("rooms"),
        .class(
          "w-full border-collapse border border-gray-200 table-fixed"
        )
      ) {
        thead { tableHeader }
        tbody {
          Rows(rooms: rooms)
        }
      }
      div(.id("roomForm")) {}
    }
  }

  private var tableHeader: some HTML<HTMLTag.tr> {
    tr {
      th(.class("border border-gray-200 text-xl font-bold")) { "Name" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Heating Load" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Cooling Total" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Cooling Sensible" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Register Count" }
      th(.class("border border-gray-200 text-xl font-bold")) {
        div(.class("flex justify-between")) {
          div {}
          button(
            .class("px-2"),
            .hx.get(route: .room(.form)),
            .hx.target("#roomForm"),
            .hx.swap(.outerHTML)
          ) {
            Icon(.circlePlus)
          }
        }
      }
    }
  }

  private struct Rows: HTML, Sendable {
    let rooms: [Room]

    var body: some HTML {
      for room in rooms {
        tr {
          td(.class("border border-gray-200 p-2")) { room.name }
          td(.class("border border-gray-200 p-2")) { "\(room.heatingLoad)" }
          td(.class("border border-gray-200 p-2")) { "\(room.coolingLoad.total)" }
          td(.class("border border-gray-200 p-2")) { "\(room.coolingLoad.sensible)" }
          td(.class("border border-gray-200 p-2")) { "\(room.registerCount)" }
          td(.class("border border-gray-200 p-2")) {
            // TODO: Add edit button.
          }
        }
      }
    }

  }
}
