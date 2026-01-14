import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Add trunk size table.

struct DuctSizingView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let rooms: [DuctSizing.RoomContainer]
  let trunks: [DuctSizing.TrunkContainer]

  var body: some HTML {
    div(.class("space-y-4")) {
      PageTitle { "Duct Sizes" }

      if rooms.count == 0 {
        p(.class("text-error italic")) {
          "Must complete all the previous sections to display duct sizing calculations."
        }
      } else {
        RoomsTable(rooms: rooms)
        div(.class("divider mb-6")) {}
      }

      Row {
        h2(.class("text-2xl font-bold")) { "Trunk Sizes" }

        PlusButton()
          .attributes(
            .class("me-6"),
            .showModal(id: TrunkSizeForm.id())
          )
      }

      if trunks.count > 0 {
        div(.class("divider -mt-2")) {}
        TrunkTable(trunks: trunks, rooms: rooms)
      }

      TrunkSizeForm(rooms: rooms, dismiss: true)
    }
  }

}
