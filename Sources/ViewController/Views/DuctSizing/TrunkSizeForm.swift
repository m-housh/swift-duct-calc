import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct TrunkSizeForm: HTML, Sendable {

  static func id(_ trunk: DuctSizes.TrunkContainer? = nil) -> String {
    let base = "trunkSizeForm"
    guard let trunk else { return base }
    return "\(base)_\(trunk.id.idString)"
  }

  @Environment(ProjectViewValue.$projectID) var projectID

  let container: DuctSizes.TrunkContainer?
  let rooms: [DuctSizes.RoomContainer]
  let dismiss: Bool

  var trunk: TrunkSize? {
    container?.trunk
  }

  init(
    trunk: DuctSizes.TrunkContainer? = nil,
    rooms: [DuctSizes.RoomContainer],
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
      h1(.class("text-lg font-bold mb-4")) { "Trunk / Runout Size" }
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
              for type in TrunkSize.TrunkType.allCases {
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

        LabeledInput(
          "Name",
          .type(.text),
          .name("name"),
          .value(trunk?.name),
          .placeholder("Trunk-1 (Optional)")
        )

        div {
          h2(.class("label font-bold col-span-3 mb-6")) { "Associated Supply Runs" }
          div(
            .class(
              """
              grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 justify-center items-center gap-4
              """
            )
          ) {
            for room in rooms {
              div(.class("block grow")) {
                div(.class("grid grid-cols-1 space-y-1")) {
                  div(.class("flex justify-center")) {
                    p(.class("label")) { room.roomName }
                  }
                  div(.class("flex justify-center")) {
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
          }
        }

        SubmitButton()
          .attributes(.class("btn-block mt-6"))
      }
    }
  }

}

extension Array where Element == TrunkSize.RoomProxy {
  func hasRoom(_ room: DuctSizes.RoomContainer) -> Bool {
    first {
      $0.id == room.roomID
        && $0.registers.contains(room.roomRegister)
    } != nil
  }
}
