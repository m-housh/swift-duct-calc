import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct DuctSizingView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let rooms: [DuctSizing.RoomContainer]
  let trunks: [DuctSizing.TrunkContainer]

  var body: some HTML {
    div(.class("space-y-4")) {
      PageTitleRow {
        div(.class("space-y-4")) {
          PageTitle("Duct Sizes")

          Alert(
            """
            Must complete all the previous sections to display duct sizing calculations.
            """
          )
          .hidden(when: rooms.count > 0)
          .attributes(.class("text-error font-bold italic"))
        }
      }

      if rooms.count != 0 {
        RoomsTable(rooms: rooms)

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

        if trunks.count > 0 {
          TrunkTable(trunks: trunks, rooms: rooms)
        }

      }

      TrunkSizeForm(rooms: rooms, dismiss: true)
    }
  }

}
