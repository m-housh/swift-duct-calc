import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

// TODO: Need to hold the project ID in hidden input field.
struct RoomForm: HTML, Sendable {

  var body: some HTML {
    div(
      .class(
        "fixed top-20 z-50 w-1/2 mx-[20vw] my-10 bg-gray-700 rounded-lg shadow-lg p-4"
      ),
      .id("roomForm")
    ) {
      h1(.class("text-3xl font-bold pb-6")) { "New Room" }
      form(
        .class(
          """
          space-y-4
          """
        )
      ) {
        div {
          label(.for("name")) { "Name:" }
          Input(id: "name", placeholder: "Room Name")
            .attributes(.type(.text), .required, .autofocus)
        }
        div {
          label(.for("heatingLoad")) { "Heating Load:" }
          Input(id: "heatingLoad", placeholder: "Heating Load")
            .attributes(.type(.number), .required, .min("0"))
        }
        div {
          label(.for("coolingLoad")) { "Cooling Load:" }
          Input(id: "coolingLoad", placeholder: "Cooling Load")
            .attributes(.type(.number), .required, .min("0"))
        }
        div {
          label(.for("registerCount")) { "Registers:" }
          Input(id: "registerCount", placeholder: "Register Count")
            .attributes(.type(.number), .required, .value("1"), .min("1"))
        }
        Row {
          // Force button to the right, probably a better way.
          div {}
          div(.class("space-x-4")) {
            CancelButton()
              .attributes(
                .hx.get(route: .room(.index)),
                .hx.target("body"),
                .hx.swap(.outerHTML)
              )
            SubmitButton()
          }
        }
        .attributes(.class("py-4"))
      }
    }
  }
}
