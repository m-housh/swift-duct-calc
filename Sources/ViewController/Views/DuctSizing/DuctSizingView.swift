import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct DuctSizingView: HTML, Sendable {
  @Environment(ShortcutViewValue.$bindings) private var bindings

  @Environment(ProjectViewValue.$projectID) var projectID

  let ductSizes: DuctSizes
  var readOnly = false

  var sortedRooms: [DuctSizes.RoomContainer] {
    ductSizes.rooms.sorted { $0.label < $1.label }
  }

  var body: some HTML {
    link(.rel(.stylesheet), .href("/css/trunks.css?v=2"))
    if !readOnly {
      link(.rel(.stylesheet), .href("/css/trunk-templates.css?v=2"))
      script(.src("/js/trunk-templates.js?v=3"), .defer) {}
      script(.src("/js/trunk-order.js?v=1"), .defer) {}
    }
    div(.class("space-y-4")) {
      PageTitleRow {
        div {
          PageTitle("Duct Sizes")
        }

        div {
          a(
            .class("btn btn-primary"),
            .init(name: "aria-keyshortcuts", value: bindings[.exportPDF]),
            .title("Export PDF in a new tab, \(bindings.label(.exportPDF))"),
            .href(route: .project(.detail(projectID, .pdf))),
            .target(.blank), .rel("noopener")
          ) {
            "PDF"
          }
        }

      }

      section(.class("project-panel trunk-panel")) {
        div(.class("project-toolbar")) {
          h2 { "Supply & return trunks" }
          button(
            .type(.button), .class("btn btn-primary"), .showModal(id: TrunkSizeForm.id()),
            .data("project-primary", value: ""),
            .init(name: "aria-keyshortcuts", value: bindings[.primaryAction]),
            .title("Add trunk, \(bindings.label(.primaryAction))")
          ) {
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
            .init(name: "aria-keyshortcuts", value: bindings[.search]))
          kbd { bindings.label(.search) }
        }
        button(
          .type(.button), .class("btn btn-primary"), .showModal(id: RectangularSizesForm.id)
        ) {
          "Rectangular sizes"
        }
      }
      div(
        .class("table-scroll"), .tabindex(0), .role("region"),
        .init(name: "aria-label", value: "Room duct sizes")
      ) {
        RoomsTable(rooms: sortedRooms)
      }

      TrunkSizeForm(rooms: sortedRooms, dismiss: true)
      RectangularSizesForm(rooms: sortedRooms)
    }
  }

}
