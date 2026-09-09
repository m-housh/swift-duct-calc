import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct RoomsView: HTML, Sendable {
  @Environment(ProjectViewValue.$projectID) var projectID
  let rooms: [Room]
  let sensibleHeatRatio: Double?

  // Sort the rooms based on level, they should already be sorted by name,
  // so this puts lower level rooms towards the top in alphabetical order.
  //
  // If rooms do not have a level we shove those all the way to the bottom.
  private var sortedRooms: [Room] {
    rooms.sorted { ($0.level?.rawValue ?? 20) < ($1.level?.rawValue ?? 20) }
  }

  var body: some HTML {
    div(.class("flex w-full flex-col")) {
      PageTitleRow {
        div(.class("flex grid grid-cols-3 w-full gap-y-4")) {

          div(.class("col-span-2")) {
            PageTitle { "Room Loads" }
          }

          div(.class("flex justify-end grow space-x-4")) {
            Tooltip("Set sensible heat ratio", position: .left) {
              button(
                .class(
                  """
                  btn btn-primary text-lg font-bold py-2 
                  """
                ),
                .showModal(id: SHRForm.id)
              ) {
                div(.class("flex grow justify-end items-end space-x-4")) {
                  span {
                    "Sensible Heat Ratio"
                  }
                  if let sensibleHeatRatio {
                    Badge(number: sensibleHeatRatio)
                    // .attributes("badge-outline")
                  } else {
                    Badge { "set" }
                    // .attributes("badge-outline")
                  }
                }
              }
              .attributes(.class("border border-error"), when: sensibleHeatRatio == nil)
            }
            .attributes(.class("tooltip-open"), when: sensibleHeatRatio == nil)

          }

          div(.class("flex items-end space-x-4 font-bold")) {
            span(.class("text-lg")) { "Heating Total" }
            Badge(number: rooms.totalHeatingLoad, digits: 0)
              .attributes(.class("badge-error"))
          }

          div(.class("flex justify-center items-end space-x-4 my-auto font-bold")) {
            span(.class("text-lg")) { "Cooling Total" }
            // TODO: ResultView ??
            Badge(number: try! rooms.totalCoolingLoad(shr: sensibleHeatRatio ?? 1.0), digits: 0)
              .attributes(.class("badge-success"))
          }

          div(.class("flex grow justify-end items-end space-x-4 me-4 my-auto font-bold")) {
            span(.class("text-lg")) { "Cooling Sensible" }
            // TODO: ResultView ??
            Badge(number: try! rooms.totalCoolingSensible(shr: sensibleHeatRatio ?? 1.0), digits: 0)
              .attributes(.class("badge-info"))
          }
        }
      }

      SHRForm(
        sensibleHeatRatio: sensibleHeatRatio,
        dismiss: true
      )

      table(.class("table table-zebra text-lg"), .id("roomsTable")) {
        thead {
          tr(.class("text-lg font-bold")) {
            th { "Name" }
            th {
              div(.class("flex justify-center")) {
                "Heating Load"
              }
            }
            th {
              div(.class("flex justify-center")) {
                "Cooling Total"
              }
            }
            th {
              div(.class("flex justify-center")) {
                "Cooling Sensible"
              }
            }
            th {
              div(.class("flex justify-center")) {
                "Register Count"
              }
            }
            th {
              div(.class("flex justify-center")) {
                "Delegated To"
              }
            }
            th {
              div(.class("flex justify-end me-2 space-x-4")) {

                Tooltip("Import room loads", position: .left) {
                  button(
                    .class("btn btn-secondary"),
                    .showModal(id: UploadRoomsForm.id)
                  ) {
                    SVG(.filePlusCorner)
                  }
                }

                Tooltip("Add Room") {
                  PlusButton()
                    .attributes(
                      .class("btn-primary mx-auto"),
                      .showModal(id: RoomForm.id())
                    )
                    .attributes(.class("tooltip-left"))
                }

              }
            }
          }
        }
        tbody {
          for room in sortedRooms {
            RoomRow(room: room, shr: sensibleHeatRatio, rooms: rooms)
          }
        }
      }
      RoomForm(dismiss: true, projectID: projectID, rooms: rooms, room: nil)
      UploadRoomsForm(hasExistingRooms: !rooms.isEmpty)
    }
  }

  public struct RoomRow: HTML, Sendable {

    let rooms: [Room]
    let room: Room
    let shr: Double

    var coolingSensible: Double {
      try! room.coolingLoad.ensured(shr: shr).sensible
    }

    var delegatedToRoomName: String? {
      guard let delegatedToID = room.delegatedTo else { return nil }
      return rooms.first(where: { $0.id == delegatedToID })?.name
    }

    init(room: Room, shr: Double?, rooms: [Room]) {
      self.room = room
      self.shr = shr ?? 1.0
      self.rooms = rooms
    }

    public var body: some HTML {
      tr(.id("roomRow_\(room.id.idString)")) {
        td {
          if let level = room.level {
            "\(level.label) - \(room.name)"
          } else {
            room.name
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(room.heatingLoad, digits: 0)
            // .attributes(.class("text-error"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(try! room.coolingLoad.ensured(shr: shr).total, digits: 0)
            // .attributes(.class("text-success"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(coolingSensible, digits: 0)
            // .attributes(.class("text-info"))
          }
        }
        td {
          div(.class("flex justify-center")) {
            Number(delegatedToRoomName != nil ? 0 : room.registerCount)
          }
        }
        td {
          if let name = delegatedToRoomName {
            div(.class("flex justify-center")) {
              name
            }
          }
        }
        td {
          div(.class("flex justify-end")) {
            div(.class("join")) {
              Tooltip("Delete room", position: .bottom) {
                TrashButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .hx.delete(
                      route: .project(.detail(room.projectID, .rooms(.delete(id: room.id))))),
                    .hx.target("closest tr"),
                    .hx.confirm("Are you sure?")
                  )
              }

              Tooltip("Edit room", position: .bottom) {
                EditButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .showModal(id: RoomForm.id(room))
                  )
              }
            }
          }
          RoomForm(
            dismiss: true,
            projectID: room.projectID,
            rooms: rooms,
            room: room
          )
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
      ModalForm(id: Self.id, dismiss: dismiss) {
        h1(.class("text-xl font-bold mb-6")) {
          "Sensible Heat Ratio"
        }
        form(
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
    let hasExistingRooms: Bool

    var body: some HTML {
      ModalForm(id: Self.id, dismiss: true) {
        h1(.class("text-2xl font-bold mb-4")) { "Import room loads" }
        label(.for("roomImportFormat"), .class("label")) { "File type" }
        select(
          .id("roomImportFormat"), .class("select w-full mb-4"),
          .on(
            .change,
            """
            this.closest('dialog').querySelectorAll('[data-import-format]').forEach(panel => {
              panel.hidden = panel.dataset.importFormat !== this.value;
            });
            """)
        ) {
          option(.value("csv")) { "CSV" }
          option(.value("pdf")) { "Cool Calc PDF" }
        }
        for format in UploadFileForm.Format.allCases {
          div(.custom(name: "data-import-format", value: format.rawValue)) {
            UploadFileForm(format: format, hasExistingRooms: hasExistingRooms)
          }
          .attributes(.hidden, when: format == .pdf)
        }
      }
    }
  }

  struct UploadFileForm: HTML {
    enum Format: String, CaseIterable {
      case csv
      case pdf
    }

    @Environment(ProjectViewValue.$projectID) var projectID
    let format: Format
    let hasExistingRooms: Bool

    private var confirmationMessage: String {
      if format == .pdf {
        return
          "This project already has rooms. Update loads and levels for matching room names and add missing rooms? Register counts, airflow delegation, and rooms absent from the file will be kept."
      }
      return
        "This project already has rooms. Update matching room names with the CSV values, including register counts and airflow delegation, and add missing rooms? Rooms absent from the file will be kept."
    }

    var body: some HTML {
      p(.class("mb-4")) {
        if format == .csv {
          "Upload a room-load CSV with names, levels, heating and cooling loads, register counts, and optional airflow delegation."
        } else {
          "Upload a Cool Calc MJ8 report. New rooms start with one register and no airflow delegation. You can edit them after import."
        }
      }
      if format == .pdf {
        p(.class("text-sm mb-4")) {
          "Maximum 10 MB and 200 pages."
        }
      }
      if hasExistingRooms {
        p(.class("text-sm mb-4")) {
          "Rooms are matched by name. Matching rooms will be updated, missing rooms will be added, and rooms absent from the file will be kept."
        }
      }
      ImportFileForm(
        action: SiteRoute.router.path(for: .view(.project(.detail(projectID, .rooms(.index)))))
          .appendingPath(format.rawValue)
      ) {
        input(
          .type(.file), .name("file"),
          .accept(format == .csv ? ".csv,text/csv" : ".pdf,application/pdf"),
          .custom(name: "aria-label", value: format == .csv ? "Room loads CSV" : "Cool Calc PDF"),
          .required)
        SubmitButton(title: "Import rooms")
          .attributes(.class("btn-block mt-6"))
        p(.class("htmx-indicator text-sm mt-2")) { "Reading room loads…" }
      }
      .attributes(.hx.confirm(confirmationMessage), when: hasExistingRooms)
    }
  }
}
