import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

extension DuctSizingView {
  struct TrunkTable: HTML, Sendable {
    let ductSizes: DuctSizes
    var body: some HTML {
      div(.class("trunk-columns")) {
        for type in [TrunkSize.TrunkType.supply, .return] {
          let trunks = ductSizes.trunks.filter { $0.type == type }.sorted {
            $0.id.uuidString < $1.id.uuidString
          }
          section(.class("trunk-column \(type.rawValue)")) {
            h3(.class("system-label \(type.rawValue)")) {
              "\(type.rawValue.capitalized) · \(trunks.count)"
            }
            for trunk in trunks { TrunkRow(trunk: trunk, rooms: ductSizes.rooms) }
            if trunks.isEmpty { p(.class("empty-state")) { "No \(type.rawValue) trunks yet." } }
          }
        }
      }
    }
  }
  struct TrunkRow: HTML, Sendable {
    @Environment(ProjectViewValue.$projectID) var projectID
    let trunk: DuctSizes.TrunkContainer
    let rooms: [DuctSizes.RoomContainer]
    private var associated: [DuctSizes.RoomContainer] {
      rooms.filter { room in
        trunk.rooms.contains { $0.id == room.roomID && $0.registers.contains(room.roomRegister) }
      }
    }
    var body: some HTML {
      article(.class("trunk-card")) {
        div(.class("trunk-card-main")) {
          SVG(.wind)
          div {
            strong { trunk.name ?? "\(trunk.type.rawValue.capitalized) trunk" }
            small { "\(associated.count) associated runs" }
            b {
              if let width = trunk.width, let height = trunk.ductSize.height {
                "\(width) × \(height) in."
              } else {
                "\(trunk.finalSize)″ round"
              }
            }
          }
          span {
            Number(trunk.designCFM.value, digits: 0)
            small { "CFM" }
          }
          TrashButton("Delete \(trunk.name ?? "trunk")").attributes(
            .class("btn-ghost"), .title("Delete trunk"),
            .hx.delete(route: .project(.detail(projectID, .ductSizing(.trunk(.delete(trunk.id)))))),
            .hx.confirm("Delete this trunk?"), .hx.target("body"), .hx.swap(.outerHTML))
          EditButton(accessibilityLabel: "Edit \(trunk.name ?? "trunk")").attributes(
            .class("btn-ghost"), .showModal(id: TrunkSizeForm.id(trunk)))
        }
        details {
          summary { "Sizes and associated runs" }
          p { "Round \(trunk.finalSize)″ · Flex \(trunk.flexSize)″ · \(trunk.velocity) FPM" }
          p {
            "Calculated diameter: "
            Number(trunk.roundSize, digits: 2)
            " in."
          }
          ul { for room in associated { li { room.label } } }
        }
        TrunkSizeForm(trunk: trunk, rooms: rooms, dismiss: true)
      }
    }
  }
}
