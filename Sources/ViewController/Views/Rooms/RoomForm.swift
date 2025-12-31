import Dependencies
import Elementary
import Foundation
import ManualDCore

// TODO: Need to hold the project ID in hidden input field.
struct RoomForm: HTML, Sendable {

  var body: some HTML {
    div(.class("mx-10 my-10")) {
      h1(.class("text-3xl font-bold pb-6")) { "Rooms " }
      form(
        .class(
          """
          grid md:grid-cols-3 gap-4
          """
        )
      ) {
        div(.class("col-span-1")) {
          div {
            label(.for("name")) { "Name:" }
          }
          input(
            .type(.text), .name("name"), .id("name"), .placeholder("Room Name"), .required,
            .autofocus
          )
        }
        div(.class("col-span-1")) {
          div {
            label(.for("heatingLoad")) { "Heating Load:" }
          }
          input(
            .type(.number), .name("heatingLoad"), .id("heatingLoad"), .placeholder("Heating Load"),
            .required
          )
        }
        div(.class("col-span-1")) {
          div {
            label(.for("coolingLoad")) { "Cooling Load:" }
          }
          input(
            .type(.number), .name("coolingLoad"), .id("coolingLoad"), .placeholder("Cooling Load"),
            .required
          )
        }
      }
    }
  }
}

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
    }
  }

  private var tableHeader: some HTML<HTMLTag.tr> {
    tr {
      th(.class("border border-gray-200 text-xl font-bold")) { "Name" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Heating Load" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Cooling Total" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Cooling Sensible" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Register Count" }
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
        }
      }
    }

  }
}
