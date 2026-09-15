import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct RoomsView: HTML, Sendable {
  @Environment(ShortcutViewValue.$bindings) private var bindings

  @Environment(ProjectViewValue.$projectID) var projectID
  let rooms: [Room]
  let sensibleHeatRatio: Double?

  private var sortedRooms: [Room] {
    rooms.sorted {
      let lhs = $0.level?.rawValue ?? 20
      let rhs = $1.level?.rawValue ?? 20
      return lhs == rhs ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : lhs < rhs
    }
  }

  var body: some HTML {
    div(.data("room-workspace", value: "")) {
      PageTitleRow {
        div {
          PageTitle { "Room loads" }
          p(.class("muted")) { "Heating and cooling loads, organized by room." }
        }
        div(.class("row-actions")) {
          button(
            .type(.button), .class("btn btn-outline"), .showModal(id: UploadRoomsForm.id),
            .init(name: "aria-keyshortcuts", value: bindings[.importLoads]),
            .title("Import loads, \(bindings.label(.importLoads))")
          ) {
            SVG(.filePlusCorner)
            "Import loads"
          }
        }
      }
      div(.class("design-metrics")) {
        DesignMetric(
          "Heating total", value: rooms.totalHeatingLoad.string(digits: 0), unit: "BTU/h")
        DesignMetric(
          "Cooling total",
          value: (try? rooms.totalCoolingLoad(shr: sensibleHeatRatio ?? 1)).map {
            $0.string(digits: 0)
          } ?? "Not set", unit: "BTU/h")
        DesignMetric(
          "Cooling sensible",
          value: (try? rooms.totalCoolingSensible(shr: sensibleHeatRatio ?? 1)).map {
            $0.string(digits: 0)
          } ?? "Not set", unit: "BTU/h")
        div(.class("design-metric shr-metric")) {
          span { "Project SHR" }
          strong { sensibleHeatRatio.map { String(format: "%.2f", $0) } ?? "Not set" }
          EditButton(accessibilityLabel: "Edit project SHR").attributes(
            .class("btn-ghost"), .showModal(id: SHRForm.id))
        }
      }
      div(.class("project-toolbar")) {
        label {
          span(.class("sr-only")) { "Filter rooms by level" }
          select(.class("select"), .data("room-level", value: "")) {
            option(.value("all")) { "All rooms" }
            for level in Array(Set(rooms.compactMap { $0.level?.rawValue })).sorted() {
              option(.value("\(level)")) { "Level \(level)" }
            }
            if rooms.contains(where: { $0.level == nil }) { option(.value("none")) { "No level" } }
          }
        }
        label(.class("project-search")) {
          span(.class("sr-only")) { "Find a room" }
          input(
            .type(.search), .id("room-search"), .class("input"), .placeholder("Find a room…"),
            .init(name: "aria-keyshortcuts", value: bindings[.search]))
          kbd { bindings.label(.search) }
        }
        button(
          .type(.button), .class("btn btn-primary"), .showModal(id: RoomForm.id()),
          .data("project-primary", value: ""),
          .init(name: "aria-keyshortcuts", value: bindings[.primaryAction]),
          .title("Add room, \(bindings.label(.primaryAction))")
        ) {
          SVG(.circlePlus)
          "Add room"
        }
      }
      div(.class("project-panel")) {
        div(
          .class("table-scroll"), .tabindex(0), .role("region"),
          .init(name: "aria-label", value: "Room loads")
        ) {
          table(
            .class("table project-table"), .id("roomsTable"),
            .data("selectable-table", value: "rooms")
          ) {
            thead {
              tr {
                th { "Room" }
                th { "Heating" }
                th { "Cooling total" }
                th { "Cooling sensible" }
                th { "Registers" }
                th { "Delegated to" }
                th { span(.class("sr-only")) { "Actions" } }
              }
            }
            tbody {
              for room in sortedRooms {
                RoomRow(room: room, shr: sensibleHeatRatio, rooms: rooms)
              }
            }
          }
        }
        p(.class("empty-state"), .data("no-rooms", value: "")) {
          rooms.isEmpty ? "Add or import rooms to get started." : "No rooms match this filter."
        }
        .attributes(.hidden, when: !rooms.isEmpty)
      }
      SHRForm(sensibleHeatRatio: sensibleHeatRatio, dismiss: true)
      RoomForm(dismiss: true, projectID: projectID, rooms: rooms, room: nil)
      UploadRoomsForm(hasExistingRooms: !rooms.isEmpty)
    }
  }

  struct RoomRow: HTML, Sendable {
    let room: Room
    let shr: Double?
    let rooms: [Room]
    var body: some HTML {
      tr(
        .id("roomRow_\(room.id.idString)"), .data("record", value: room.id.idString),
        .data("search", value: room.name),
        .data("level", value: room.level.map { "\($0.rawValue)" } ?? "none")
      ) {
        td {
          button(.type(.button), .class("row-select"), .init(name: "aria-pressed", value: "false"))
          {
            room.name
            small { room.level?.label ?? "No level" }
          }
        }
        td { Number(room.heatingLoad, digits: 0) }
        td {
          if let load = try? room.coolingLoad.ensured(shr: shr ?? 1) {
            Number(load.total, digits: 0)
          } else {
            "Not set"
          }
        }
        td {
          if let load = try? room.coolingLoad.ensured(shr: shr ?? 1) {
            Number(load.sensible, digits: 0)
          } else {
            "Not set"
          }
        }
        td { Number(room.delegatedTo == nil ? room.registerCount : 0) }
        td { rooms.first(where: { $0.id == room.delegatedTo })?.name ?? "—" }
        td {
          div(.class("row-actions")) {
            TrashButton("Delete \(room.name)").attributes(
              .class("btn-ghost"),
              .hx.delete(route: .project(.detail(room.projectID, .rooms(.delete(id: room.id))))),
              .hx.target("body"), .hx.swap(.outerHTML), .hx.confirm("Delete this room?"))
            EditButton(accessibilityLabel: "Edit \(room.name)").attributes(
              .class("btn-ghost"), .showModal(id: RoomForm.id(room)))
          }
          RoomForm(dismiss: true, projectID: room.projectID, rooms: rooms, room: room)
        }
      }
    }
  }

  struct SHRForm: HTML, Sendable {
    static let id = "shrForm"

    @Environment(ProjectViewValue.$projectID) var projectID
    let sensibleHeatRatio: Double?
    let dismiss: Bool

    var route: String {
      SiteRoute.View.router
        .path(for: .project(.detail(projectID, .rooms(.index))))
        .appendingPath("update-shr")
    }

    var body: some HTML {
      ModalForm(id: Self.id, title: "Sensible Heat Ratio", dismiss: dismiss) {
        form(
          .data("success-message", value: "Sensible heat ratio saved."),
          .class("grid grid-cols-1 gap-4"),
          .hx.patch(route),
          .hx.target("body"),
          .hx.swap(.outerHTML)
        ) {
          input(.class("hidden"), .name("projectID"), .value("\(projectID)"))
          LabeledInput(
            "SHR",
            .name("sensibleHeatRatio"),
            .type(.number),
            .value(sensibleHeatRatio),
            .placeholder("0.83"),
            .min("0"),
            .max("1"),
            .step("0.01"),
            .autofocus
          )
          SubmitButton()
            .attributes(.class("btn-block my-6"))
        }
      }
    }
  }

  struct UploadRoomsForm: HTML {
    static let id = "uploadRooms"
    @Environment(ProjectViewValue.$projectID) var projectID
    let hasExistingRooms: Bool

    private func action(_ format: String) -> String {
      SiteRoute.router.path(for: .view(.project(.detail(projectID, .rooms(.index)))))
        .appendingPath(format)
    }

    var body: some HTML {
      ModalForm(id: Self.id, title: "Import room loads", dismiss: true) {
        p(.class("mb-4")) {
          "Import a room-load CSV with names, levels, heating and cooling loads, register counts, and optional airflow delegation, or a Cool Calc MJ8 report. Rooms from a report start with one register and no airflow delegation."
        }
        ImportFileForm(
          action: action("csv"),
          prompt: "Drop a room-load CSV or Cool Calc MJ8 report",
          limits: "CSV, or PDF up to 10 MB and 200 pages",
          accept: ".csv,text/csv,.pdf,application/pdf",
          fileTypes: "room-load CSV or Cool Calc MJ8 report PDF",
          reading: "Reading room loads…"
        ) {
          div(.data("import-when", value: "chosen"), .hidden) {
            if hasExistingRooms {
              p(.class("mt-4 text-sm"), .data("import-format", value: "csv")) {
                "This project already has rooms. Rooms are matched by name: matching rooms are updated with the CSV values, including register counts and airflow delegation, and missing rooms are added. Rooms absent from the file are kept."
              }
              p(.class("mt-4 text-sm"), .data("import-format", value: "pdf")) {
                "This project already has rooms. Rooms are matched by name: matching rooms get the report's loads and levels, and missing rooms are added. Register counts, airflow delegation, and rooms absent from the report are kept."
              }
            }
            SubmitButton(title: "Import rooms")
              .attributes(.class("btn-block mt-4"))
          }
        }
        .attributes(.data("import-action-pdf", value: action("pdf")))
      }
    }
  }
}
