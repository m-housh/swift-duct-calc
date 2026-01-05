import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

// TODO: Need to hold the project ID in hidden input field.
struct RoomForm: HTML, Sendable {

  let dismiss: Bool
  let projectID: Project.ID
  let room: Room?

  var body: some HTML {
    ModalForm(id: "roomForm", dismiss: dismiss) {
      h1(.class("text-3xl font-bold pb-6")) { "Room" }
      // TODO: Use htmx here.
      form(
        room == nil
          ? .hx.post(route: .project(.detail(projectID, .rooms(.index))))
          : .hx.patch(route: .project(.detail(projectID, .rooms(.index)))),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {

        input(.class("hidden"), .name("projectID"), .value("\(projectID)"))

        if let id = room?.id {
          input(.class("hidden"), .name("id"), .value("\(id)"))
        }

        div {
          label(.for("name")) { "Name:" }
          Input(id: "name", placeholder: "Room Name")
            .attributes(.type(.text), .required, .autofocus, .value(room?.name))
        }
        div {
          label(.for("heatingLoad")) { "Heating Load:" }
          Input(id: "heatingLoad", placeholder: "Heating Load")
            .attributes(.type(.number), .required, .min("0"), .value(room?.heatingLoad))
        }
        div {
          label(.for("coolingLoad")) { "Cooling Load:" }
          Input(id: "coolingLoad", placeholder: "Cooling Load")
            .attributes(.type(.number), .required, .min("0"), .value(room?.coolingLoad))
        }
        div {
          label(.for("registerCount")) { "Registers:" }
          Input(id: "registerCount", placeholder: "Register Count")
            .attributes(
              .type(.number), .required, .min("0"),
              .value("\(room != nil ? room!.registerCount : 1)"),
            )
        }
        Row {
          // Force button to the right, probably a better way.
          div {}
          div(.class("space-x-4")) {
            CancelButton()
              .attributes(
                .hx.get(route: .project(.detail(projectID, .rooms(.form(dismiss: true))))),
                .hx.target("#roomForm"),
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
