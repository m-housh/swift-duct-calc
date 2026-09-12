import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct DuctSizingView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let ductSizes: DuctSizes

  var sortedRooms: [DuctSizes.RoomContainer] {
    ductSizes.rooms.sorted { $0.label < $1.label }
  }

  var body: some HTML {
    div(.class("space-y-4")) {
      PageTitleRow {
        div {
          PageTitle("Duct Sizes")
        }

        div {
          button(
            .class("btn btn-primary"),
            .hx.get(route: .project(.detail(projectID, .pdf))),
            .hx.ext("htmx-download"),
            .hx.swap(.none),
            .hx.indicator()
          ) {
            span { "PDF" }
            Indicator()
          }
          // div {
          //   Indicator()
          // }
        }

      }

      section(.class("project-panel trunk-panel")) {
        div(.class("project-toolbar")) {
          h2 { "Supply & return trunks" }
          button(.type(.button), .class("btn btn-primary"), .showModal(id: TrunkSizeForm.id())) {
            SVG(.circlePlus)
            "Add trunk"
          }
        }
        TrunkTable(ductSizes: ductSizes)
      }
      div(.class("project-toolbar")) {
        h2 { "Branch schedule" }
        label(.class("project-search")) {
          span(.class("sr-only")) { "Find a register" }
          input(
            .type(.search), .class("input"), .id("register-search"), .placeholder("Find a room…"),
            .init(name: "aria-keyshortcuts", value: "Control+K"))
        }
      }
      div(
        .class("table-scroll"), .tabindex(0), .role("region"),
        .init(name: "aria-label", value: "Room duct sizes")
      ) {
        RoomsTable(rooms: sortedRooms)
      }

      TrunkSizeForm(rooms: sortedRooms, dismiss: true)
    }
  }

}
