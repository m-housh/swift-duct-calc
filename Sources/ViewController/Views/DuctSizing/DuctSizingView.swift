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

      if ductSizes.rooms.count != 0 {
        RoomsTable(rooms: sortedRooms)

        PageTitleRow {
          PageTitle {
            "Trunk / Runout Sizes"
          }

          PlusButton("Add trunk or runout")
            .attributes(
              .class("btn-primary"),
              .showModal(id: TrunkSizeForm.id())
            )
            .tooltip("Add trunk / runout")
        }

        if ductSizes.trunks.count > 0 {
          TrunkTable(ductSizes: ductSizes)
        }

      }

      TrunkSizeForm(rooms: sortedRooms, dismiss: true)
    }
  }

}
