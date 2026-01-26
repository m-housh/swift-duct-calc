import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct DuctSizingView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let ductSizes: DuctSizes

  var body: some HTML {
    div(.class("space-y-4")) {
      PageTitleRow {
        div {
          PageTitle("Duct Sizes")

          Alert(
            """
            Must complete all the previous sections to display duct sizing calculations.
            """
          )
          .hidden(when: ductSizes.rooms.count > 0)
          .attributes(.class("text-error font-bold italic mt-4"))
        }

        a(
          .class("btn btn-primary"),
          .href(route: .project(.detail(projectID, .pdf)))
        ) {
          "PDF"
        }

      }

      if ductSizes.rooms.count != 0 {
        RoomsTable(rooms: ductSizes.rooms)

        PageTitleRow {
          PageTitle {
            "Trunk / Runout Sizes"
          }

          PlusButton()
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

      TrunkSizeForm(rooms: ductSizes.rooms, dismiss: true)
    }
  }

}
