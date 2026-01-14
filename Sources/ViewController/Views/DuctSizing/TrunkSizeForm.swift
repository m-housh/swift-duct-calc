import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct TrunkSizeForm: HTML, Sendable {

  static func id(_ trunk: DuctSizing.TrunkContainer? = nil) -> String {
    let base = "trunkSizeForm"
    guard let trunk else { return base }
    return "\(base)_\(trunk.id.idString)"
  }

  @Environment(ProjectViewValue.$projectID) var projectID

  let container: DuctSizing.TrunkContainer?
  let rooms: [DuctSizing.RoomContainer]
  let dismiss: Bool

  var trunk: DuctSizing.TrunkSize? {
    container?.trunk
  }

  init(
    trunk: DuctSizing.TrunkContainer? = nil,
    rooms: [DuctSizing.RoomContainer],
    dismiss: Bool = true
  ) {
    self.container = trunk
    self.rooms = rooms
    self.dismiss = dismiss
  }

  var route: String {
    SiteRoute.View.router
      .path(for: .project(.detail(projectID, .ductSizing(.index))))
      .appendingPath(SiteRoute.View.ProjectRoute.DuctSizingRoute.TrunkRoute.rootPath)
      .appendingPath(trunk?.id)
  }

  var body: some HTML {
    ModalForm(id: Self.id(container), dismiss: dismiss) {
      h1(.class("text-lg font-bold mb-4")) { "Trunk Size" }
      form(
        .class("space-y-4"),
        trunk == nil
          ? .hx.post(route)
          : .hx.patch(route),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {

        input(.class("hidden"), .name("projectID"), .value(projectID))

        div(.class("grid grid-cols-1 md:grid-cols-2 gap-4")) {
          label(.class("select w-full")) {
            span(.class("label")) { "Type" }
            select(.name("type")) {
              for type in DuctSizing.TrunkSize.TrunkType.allCases {
                option(.value(type.rawValue)) { type.rawValue.capitalized }
                  .attributes(.selected, when: trunk?.type == type)
              }
            }
          }

          LabeledInput(
            "Height",
            .type(.text),
            .name("height"),
            .value(trunk?.height),
            .placeholder("8 (Optional)"),
          )
        }

        // Add room select here.
        div(.class("grid grid-cols-5 gap-6")) {
          h2(.class("label font-bold col-span-5")) { "Associated Supply Runs" }
          for room in rooms {
            div(.class("flex justify-center items-center col-span-1")) {
              div(.class("space-y-1")) {
                p(.class("label block")) { room.registerID }
                input(
                  .class("checkbox"),
                  .type(.checkbox),
                  .name("rooms"),
                  .value("\(room.roomID)_\(room.roomRegister)")
                )
                .attributes(
                  .checked,
                  when: trunk == nil ? false : trunk!.rooms.hasRoom(room)
                )
              }
            }
          }
        }

        SubmitButton()
          .attributes(.class("btn-block"))
      }
    }
  }

}

extension Array where Element == DuctSizing.TrunkSize.RoomProxy {
  func hasRoom(_ room: DuctSizing.RoomContainer) -> Bool {
    first {
      $0.id == room.roomID
        && $0.registers.contains(room.roomRegister)
    } != nil
  }
}
