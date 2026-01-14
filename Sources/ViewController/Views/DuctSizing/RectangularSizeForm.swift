import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct RectangularSizeForm: HTML, Sendable {

  static func id(_ roomID: Room.ID? = nil) -> String {
    let base = "rectangularSize"
    guard let roomID else { return base }
    return "\(base)_\(roomID.idString)"
  }

  static func id(_ room: DuctSizing.RoomContainer) -> String {
    return id(room.roomID)
  }

  @Environment(ProjectViewValue.$projectID) var projectID

  let id: String
  let roomID: Room.ID
  let rectangularSizeID: DuctSizing.RectangularDuct.ID?
  let register: Int
  let height: Int?
  let dismiss: Bool

  init(
    id: String? = nil,
    roomID: Room.ID,
    rectangularSizeID: DuctSizing.RectangularDuct.ID? = nil,
    register: Int,
    height: Int? = nil,
    dismiss: Bool = true
  ) {
    self.id = id ?? Self.id(roomID)
    self.roomID = roomID
    self.rectangularSizeID = rectangularSizeID
    self.register = register
    self.height = height
    self.dismiss = dismiss
  }

  init(
    id: String? = nil,
    room: DuctSizing.RoomContainer,
    dismiss: Bool = true
  ) {
    let register =
      room.rectangularSize?.register
      ?? (Int("\(room.roomName.last!)") ?? 1)

    self.init(
      id: id,
      roomID: room.roomID,
      rectangularSizeID: room.rectangularSize?.id,
      register: register,
      height: room.rectangularSize?.height,
      dismiss: dismiss
    )
  }

  var route: String {
    SiteRoute.View.router.path(
      for: .project(.detail(projectID, .ductSizing(.index)))
    )
    .appendingPath("room")
    .appendingPath(roomID)

  }

  var body: some HTML<HTMLTag.dialog> {
    ModalForm(id: id, dismiss: dismiss) {

      h1(.class("text-lg pb-6")) { "Rectangular Size" }

      form(
        .class("space-y-4"),
        .hx.post(route),
        .hx.target("closest tr"),
        .hx.swap(.outerHTML)
      ) {
        input(.class("hidden"), .name("register"), .value(register))
        input(.class("hidden"), .name("id"), .value(rectangularSizeID))

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
