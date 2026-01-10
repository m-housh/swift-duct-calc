import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct RectangularSizeForm: HTML, Sendable {

  static func id(_ roomID: Room.ID? = nil) -> String {
    let base = "rectangularSizeForm"
    guard let roomID else { return base }
    return "\(base)_\(roomID.idString)"
  }

  static func id(_ room: DuctSizing.RoomContainer) -> String {
    return id(room.roomID)
  }

  let projectID: Project.ID
  let roomID: Room.ID
  let rectangularSizeID: DuctSizing.RectangularDuct.ID?
  let register: Int
  let height: Int?
  let dismiss: Bool

  init(
    projectID: Project.ID,
    roomID: Room.ID,
    rectangularSizeID: DuctSizing.RectangularDuct.ID? = nil,
    register: Int,
    height: Int? = nil,
    dismiss: Bool = true
  ) {
    self.projectID = projectID
    self.roomID = roomID
    self.rectangularSizeID = rectangularSizeID
    self.register = register
    self.height = height
    self.dismiss = dismiss
  }

  init(
    projectID: Project.ID,
    room: DuctSizing.RoomContainer,
    dismiss: Bool = true
  ) {
    let register =
      room.rectangularSize?.register
      ?? (Int("\(room.roomName.last!)") ?? 1)

    self.init(
      projectID: projectID,
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

  var body: some HTML {
    ModalForm(id: Self.id(roomID), dismiss: dismiss) {

      h1(.class("text-lg pb-6")) { "Rectangular Size" }

      form(
        .class("space-y-4"),
        .hx.post(route),
        .hx.target("closest tr"),
        .hx.swap(.outerHTML)
      ) {
        input(.class("hidden"), .name("register"), .value(register))
        input(.class("hidden"), .name("id"), .value(rectangularSizeID))

        Input(id: "height", placeholder: "Height")
          .attributes(.type(.number), .min("0"), .value(height), .required, .autofocus)

        SubmitButton()
          .attributes(.class("btn-block"))
      }

    }
  }
}
