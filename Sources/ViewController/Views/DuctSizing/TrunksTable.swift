import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

extension DuctSizingView {
  struct TrunkTable: HTML, Sendable {
    @Environment(ProjectViewValue.$projectID) var projectID
    let ductSizes: DuctSizes
    var body: some HTML {
      div(.class("trunk-columns")) {
        for type in [TrunkSize.TrunkType.supply, .return] {
          let trunks = ductSizes.trunks.filter { $0.type == type }
          section(
            .class("trunk-column \(type.rawValue)"),
            .data("trunk-type", value: type.rawValue),
            .data(
              "trunk-order-url",
              value: SiteRoute.View.router.path(
                for: .project(.detail(projectID, .ductSizing(.trunk(.reorder(type, [])))))))
          ) {
            h3(.class("system-label \(type.rawValue)")) {
              "\(type.rawValue.capitalized) · \(trunks.count)"
            }
            if !trunks.isEmpty {
              div(.class("trunk-column-head"), .init(name: "aria-hidden", value: "true")) {
                span {}
                span { "Trunk" }
                span { "CFM" }
                span { "Round" }
                span { "Flex" }
                span { "Rectangular" }
              }
            }
            for trunk in trunks { TrunkRow(trunk: trunk, rooms: ductSizes.rooms) }
            if trunks.isEmpty { p(.class("empty-state")) { "No \(type.rawValue) trunks yet." } }
            p(
              .class("trunk-order-status"), .role("status"),
              .init(name: "aria-live", value: "polite")
            ) {}
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
      article(.class("trunk-card"), .data("trunk-id", value: trunk.id.uuidString)) {
        div(.class("trunk-card-main")) {
          button(
            .type(.button), .class("trunk-drag-handle"),
            .data("trunk-name", value: trunk.name ?? "\(trunk.type.rawValue) trunk"),
            .init(name: "aria-label", value: "Reorder \(trunk.name ?? "trunk")"),
            .title("Drag to reorder, or use the Up and Down arrow keys")
          ) { span(.init(name: "aria-hidden", value: "true")) { "↕" } }
          div(.class("trunk-card-identity")) {
            strong { trunk.name ?? "\(trunk.type.rawValue.capitalized) trunk" }
            small { "\(associated.count) associated runs" }
          }
          dl(.class("trunk-card-sizes")) {
            div(.class("trunk-airflow")) {
              dt { "CFM" }
              dd { Number(trunk.designCFM.value, digits: 0) }
            }
            div {
              dt { "Round" }
              dd { span(.class("size-chip")) { "\(trunk.finalSize)″" } }
            }
            div {
              dt { "Flex" }
              dd { "\(trunk.flexSize)″" }
            }
            div {
              dt { "Rectangular" }
              dd {
                if let width = trunk.width, let height = trunk.ductSize.height {
                  "\(width) × \(height) in."
                } else {
                  span(
                    .class("trunk-size-empty"),
                    .init(name: "aria-label", value: "No rectangular size")
                  ) {
                    "—"
                  }
                }
              }
            }
          }
        }
        div(.class("trunk-card-footer")) {
          details {
            summary(.init(name: "aria-label", value: "Calculation details and associated runs")) {
              "Details & runs"
            }
            p { "Velocity: \(trunk.velocity) FPM" }
            p {
              "Calculated diameter: "
              Number(trunk.roundSize, digits: 2)
              " in."
            }
            ul { for room in associated { li { room.label } } }
          }
          div(.class("trunk-card-actions")) {
            TrashButton("Delete \(trunk.name ?? "trunk")").attributes(
              .class("btn-ghost"), .title("Delete trunk"),
              .hx.delete(
                route: .project(.detail(projectID, .ductSizing(.trunk(.delete(trunk.id)))))),
              .hx.confirm("Delete this trunk?"), .hx.target("body"), .hx.swap(.outerHTML))
            EditButton(accessibilityLabel: "Edit \(trunk.name ?? "trunk")").attributes(
              .class("btn-ghost"), .showModal(id: TrunkSizeForm.id(trunk)))
          }
        }
        TrunkSizeForm(trunk: trunk, rooms: rooms, dismiss: true)
      }
    }
  }
}
