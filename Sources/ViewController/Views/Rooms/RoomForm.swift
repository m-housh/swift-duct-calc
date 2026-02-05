import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

// TODO: Need to hold the project ID in hidden input field.
struct RoomForm: HTML, Sendable {

  static func id(_ room: Room? = nil) -> String {
    let baseId = "roomForm"
    guard let room else { return baseId }
    return baseId.appending("_\(room.id.idString)")
  }

  let dismiss: Bool
  let projectID: Project.ID
  let room: Room?

  init(
    dismiss: Bool,
    projectID: Project.ID,
    room: Room? = nil
  ) {
    self.dismiss = dismiss
    self.projectID = projectID
    self.room = room
  }

  var route: String {
    SiteRoute.View.router.path(
      for: .project(.detail(projectID, .rooms(.index)))
    )
    .appendingPath(room?.id)
  }

  var body: some HTML {
    ModalForm(id: Self.id(room), dismiss: dismiss) {
      h1(.class("text-3xl font-bold pb-6")) { "Room" }
      form(
        .class("grid grid-cols-1 gap-4"),
        room == nil
          ? .hx.post(route)
          : .hx.patch(route),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {

        if let id = room?.id {
          input(.class("hidden"), .name("id"), .value("\(id)"))
        }

        LabeledInput(
          "Name",
          .name("name"),
          .type(.text),
          .placeholder("Name"),
          .required,
          .autofocus,
          .value(room?.name)
        )

        LabeledInput(
          "Heating Load",
          .name("heatingLoad"),
          .type(.number),
          .placeholder("1234"),
          .required,
          .min("0"),
          .value(room?.heatingLoad)
        )

        // TODO: Add description that only one is required (cooling total or sensible)

        LabeledInput(
          "Cooling Total",
          .name("coolingTotal"),
          .type(.number),
          .placeholder("1234 (Optional)"),
          .min("0"),
          .value(room?.coolingLoad.total)
        )

        LabeledInput(
          "Cooling Sensible",
          .name("coolingSensible"),
          .type(.number),
          .placeholder("1234 (Optional)"),
          .min("0"),
          .value(room?.coolingLoad.sensible)
        )

        LabeledInput(
          "Registers",
          .name("registerCount"),
          .type(.number),
          .min("1"),
          .required,
          .value(room?.registerCount ?? 1)
        )

        SubmitButton()
          .attributes(.class("btn-block"))
      }
    }
  }
}
