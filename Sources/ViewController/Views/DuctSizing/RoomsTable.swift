import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

extension DuctSizingView {
  struct RoomsTable: HTML, Sendable {
    let rooms: [DuctSizes.RoomContainer]
    var body: some HTML<HTMLTag.table> {
      table(.class("table project-table"), .data("selectable-table", value: "registers")) {
        thead {
          tr {
            th { "Room / register" }
            th { "Design CFM" }
            th { "Velocity" }
            th { "Round" }
            th { "Flex" }
            th { "Rectangular" }
            th { span(.class("sr-only")) { "Actions" } }
          }
        }
        tbody { for room in rooms { RoomRow(room: room) } }
      }
    }
  }
  struct RoomRow: HTML, Sendable {
    static func id(_ room: DuctSizes.RoomContainer) -> String {
      "roomRow_\(room.roomID.idString)_\(room.roomRegister)"
    }
    @Environment(ProjectViewValue.$projectID) var projectID
    let room: DuctSizes.RoomContainer
    var deleteRoute: String {
      guard let id = room.rectangularID else { return "" }

      return SiteRoute.View.router.path(
        for: .project(
          .detail(
            projectID,
            .ductSizing(
              .deleteRectangularSize(
                room.roomID,
                .init(rectangularSizeID: id, register: room.roomRegister)
              ))
          )
        )
      )
    }

    var rowID: String { Self.id(room) }

    var body: some HTML<HTMLTag.tr> {
      tr(.id(rowID), .data("record", value: rowID), .data("search", value: room.roomName)) {
        td {
          button(.type(.button), .class("row-select"), .init(name: "aria-pressed", value: "false"))
          {
            room.roomName
            small { "\(room.roomLevel?.label ?? "No level") · Register \(room.roomRegister)" }
          }
        }
        td {
          details(.data("expansion", value: "airflow-\(rowID)")) {
            summary { Number(room.designCFM.value, digits: 0) }
            p {
              "Heating: "
              Number(room.heatingCFM, digits: 0)
              " CFM · "
              Number(room.heatingLoad, digits: 0)
              " BTU/h"
            }
            p {
              "Cooling: "
              Number(room.coolingCFM, digits: 0)
              " CFM · "
              Number(room.coolingLoad, digits: 0)
              " BTU/h"
            }
          }
        }
        td {
          Number(room.velocity)
          " FPM"
        }
        td {
          span(.title("Calculated diameter: \(room.roundSize) in."), .class("size-chip")) {
            "\(room.finalSize)″"
          }
        }
        td { "\(room.flexSize)″" }
        td {
          if let width = room.width, let height = room.height {
            "\(width) × \(height) in."
          } else {
            "—"
          }
        }
        td {
          div(.class("row-actions")) {
            if room.width != nil {
              TrashButton("Clear rectangular size for \(room.label)").attributes(
                .class("btn-ghost"), .hx.delete(deleteRoute), .hx.target("#\(rowID)"),
                .hx.swap(.outerHTML))
            }
            EditButton(accessibilityLabel: "Edit rectangular size for \(room.label)").attributes(
              .class("btn-ghost"), .showModal(id: RectangularSizeForm.id(room)))
          }
          RectangularSizeForm(room: room)
        }
      }
    }
  }
}
