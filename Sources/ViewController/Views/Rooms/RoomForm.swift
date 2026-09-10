import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct RoomForm: HTML, Sendable {

  static func id(_ room: Room? = nil) -> String {
    let baseId = "roomForm"
    guard let room else { return baseId }
    return baseId.appending("_\(room.id.idString)")
  }

  let dismiss: Bool
  let projectID: Project.ID
  let room: Room?
  let rooms: [Room]

  init(
    dismiss: Bool,
    projectID: Project.ID,
    rooms: [Room],
    room: Room? = nil
  ) {
    self.dismiss = dismiss
    self.projectID = projectID
    self.rooms = rooms
    self.room = room
  }

  private var route: String {
    SiteRoute.View.router.path(
      for: .project(.detail(projectID, .rooms(.index)))
    )
    .appendingPath(room?.id)
  }

  private var selectableRooms: [Room] {
    rooms.filter { $0.delegatedTo == nil }
  }

  var body: some HTML {
    ModalForm(id: Self.id(room), title: "Room", dismiss: dismiss) {

      form(
        .data("success-message", value: "Changes saved."),
        .class("grid grid-cols-1 gap-4"),
        room == nil
          ? .hx.post(route)
          : .hx.patch(route),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {

        if let id = room?.id {
          input(.class("hidden"), .name("id"), .value("\(id)"))
        }

        LabeledInput(
          "Name",
          .name("name"),
          .type(.text),
          .placeholder("Name"),
          .required,
          .autofocus,
          .value(room?.name)
        )

        LabeledInput(
          "Level (optional)",
          .name("level"),
          .init(name: "aria-describedby", value: "\(Self.id(room))-level-help"),
          .type(.number),
          .placeholder("1 (Optional)"),
          .value(room?.level?.rawValue),
          .min("-1"),
          .step("1")
        )
        div(.id("\(Self.id(room))-level-help"), .class("text-sm italic -mt-2")) {
          span {
            "Use -1 or 0 for a basement"
          }
        }

        LabeledInput(
          "Heating Load",
          .name("heatingLoad"),
          .type(.number),
          .placeholder("1234"),
          .required,
          .min("0"),
          .value(room?.heatingLoad)
        )

        LabeledInput(
          "Cooling Total",
          .name("coolingTotal"),
          .init(name: "aria-describedby", value: "\(Self.id(room))-cooling-help"),
          .type(.number),
          .placeholder("1234 (Optional)"),
          .min("0"),
          .value(room?.coolingLoad.total)
        )

        LabeledInput(
          "Cooling Sensible",
          .name("coolingSensible"),
          .init(name: "aria-describedby", value: "\(Self.id(room))-cooling-help"),
          .type(.number),
          .placeholder("1234 (Optional)"),
          .min("0"),
          .value(room?.coolingLoad.sensible)
        )
        div(.id("\(Self.id(room))-cooling-help"), .class("text-sm italic -mt-2")) {
          p {
            "Should enter at least one of the cooling loads."
          }
          p {
            "Both are also acceptable."
          }
        }

        LabeledInput(
          "Registers",
          .name("registerCount"),
          .type(.number),
          .min("1"),
          .required,
          .value(room?.registerCount ?? 1)
        )

        label(.class("select w-full")) {
          span(.class("label")) { "Room" }
          Select(selectableRooms, label: \.name, placeholder: "Delegate Airflow")
            .attributes(.name("delegatedTo"))
        }

        SubmitButton()
          .attributes(.class("btn-block"))
      }
    }
  }
}
