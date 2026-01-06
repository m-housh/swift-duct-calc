import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

// TODO: Need to hold the project ID in hidden input field.
struct RoomForm: HTML, Sendable {

  static let id = "roomForm"

  let dismiss: Bool
  let projectID: Project.ID
  let room: Room?

  var body: some HTML {
    ModalForm(id: Self.id, dismiss: dismiss) {
      h1(.class("text-3xl font-bold pb-6")) { "Room" }
      // TODO: Use htmx here.
      form(
        .class("modal-backdrop"),
        .init(name: "method", value: "dialog"),
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
          label(.for("coolingTotal")) { "Cooling Total:" }
          Input(id: "coolingTotal", placeholder: "Cooling Total")
            .attributes(.type(.number), .required, .min("0"), .value(room?.coolingTotal))
        }
        div {
          label(.for("coolingSensible")) { "Cooling Sensible:" }
          Input(id: "coolingSensible", placeholder: "Cooling Sensible (Optional)")
            .attributes(.type(.number), .min("0"), .value(room?.coolingSensible))
        }
        div(.class("pb-6")) {
          label(.for("registerCount")) { "Registers:" }
          Input(id: "registerCount", placeholder: "Register Count")
            .attributes(
              .type(.number), .required, .min("0"),
              .value("\(room != nil ? room!.registerCount : 1)"),
            )
        }
        div(.class("flex justify-end space-x-4")) {
          SubmitButton()
        }
      }
    }
  }
}
