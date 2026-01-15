import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct RectangularSizeForm: HTML, Sendable {

  static func id(_ room: DuctSizing.RoomContainer) -> String {
    let base = "rectangularSize"
    return "\(base)_\(room.roomName.idString)"
  }

  @Environment(ProjectViewValue.$projectID) var projectID

  let id: String
  let room: DuctSizing.RoomContainer
  let dismiss: Bool

  init(
    id: String? = nil,
    room: DuctSizing.RoomContainer,
    dismiss: Bool = true
  ) {
    self.id = Self.id(room)
    self.room = room
    self.dismiss = dismiss
  }

  var route: String {
    SiteRoute.View.router.path(
      for: .project(.detail(projectID, .ductSizing(.index)))
    )
    .appendingPath("room")
    .appendingPath(room.roomID)

  }

  var rowID: String {
    DuctSizingView.RoomRow.id(room)
  }

  var height: Int? {
    room.rectangularSize?.height
  }

  var body: some HTML<HTMLTag.dialog> {
    ModalForm(id: id, dismiss: dismiss) {
      h1(.class("text-lg pb-6")) { "Rectangular Size" }

      form(
        .class("space-y-4"),
        .hx.post(route),
        .hx.target("#\(rowID)"),
        .hx.swap(.outerHTML)
      ) {
        input(.class("hidden"), .name("register"), .value(room.roomRegister))
        input(.class("hidden"), .name("id"), .value(room.rectangularSize?.id))

        LabeledInput(
          "Height",
          .name("height"),
          .type(.number),
          .value(height),
          .placeholder("8"),
          .min("0"),
          .required,
          .autofocus
        )

        SubmitButton()
          .attributes(.class("btn-block"))
      }

    }
  }
}
