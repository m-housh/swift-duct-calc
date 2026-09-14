import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

/// Sets or clears rectangular sizes on the chosen registers of the branch schedule.
struct RectangularSizesForm: HTML, Sendable {

  static let id = "rectangularSizesForm"

  @Environment(ProjectViewValue.$projectID) var projectID

  let rooms: [DuctSizes.RoomContainer]

  var route: String {
    SiteRoute.View.router
      .path(for: .project(.detail(projectID, .ductSizing(.index))))
      .appendingPath(SiteRoute.View.ProjectRoute.DuctSizingRoute.rectangularSizesPath)
  }

  var body: some HTML {
    ModalForm(id: Self.id, title: "Rectangular Sizes", dismiss: true) {
      form(
        .data("success-message", value: "Changes saved."),
        .class("space-y-4"),
        .hx.post(route),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {
        LabeledInput(
          "Height",
          .name("height"),
          .type(.number),
          .placeholder("8"),
          .min("1"),
          .required,
          .autofocus
        )

        supplyRuns

        div(.class("flex flex-wrap gap-2 mt-6")) {
          button(.type(.submit), .class("btn btn-secondary")) { "Set height" }
          button(
            .type(.button), .class("btn btn-error btn-outline"),
            .hx.post(route.appendingPath("clear")),
            .hx.include("closest form"),
            .hx.params("rooms")
          ) {
            "Clear rectangular sizes"
          }
        }
      }
    }
  }

  var supplyRuns: some HTML<HTMLTag.fieldset> & Sendable {
    CheckboxGroup(
      "Supply Runs",
      name: "rooms",
      options: rooms.map { room in
        let currentSize: String?
        if let width = room.width, let height = room.height {
          currentSize = "\(width) × \(height) in."
        } else {
          currentSize = nil
        }
        return .init(
          value: "\(room.roomID)_\(room.roomRegister)",
          label: room.label,
          badge: currentSize
        )
      }
    )
    .attributes(.id("rectangularSizesSupplyRuns"))
  }
}
