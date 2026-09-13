import Elementary
import ManualDCore
import Styleguide

struct EquipmentInfoForm: HTML, Sendable {
  enum Field: String, CaseIterable {
    case all, heating, cooling, pressure

    var id: String { "equipmentForm-\(rawValue)" }
    var title: String {
      switch self {
      case .all: "Edit equipment"
      case .heating: "Heating airflow"
      case .cooling: "Cooling airflow"
      case .pressure: "External static pressure"
      }
    }
    var key: String {
      switch self {
      case .all: "E"
      case .heating: "H"
      case .cooling: "C"
      case .pressure: "S"
      }
    }
  }

  @Environment(ProjectViewValue.$projectID) var projectID
  let equipmentInfo: EquipmentInfo?
  var field: Field = .all

  var route: String {
    SiteRoute.View.router.path(for: .project(.detail(projectID, .equipment(.index))))
      .appendingPath(equipmentInfo?.id)
  }

  var body: some HTML {
    ModalForm(id: field.id, title: field.title, dismiss: true) {
      form(
        .data("equipment-form", value: field.rawValue),
        .data("success-message", value: "Equipment saved."),
        .class("grid grid-cols-1 gap-4"),
        equipmentInfo != nil ? .hx.patch(route) : .hx.post(route),
        .hx.target("body"), .hx.swap(.outerHTML)
      ) {
        input(.type(.hidden), .name("projectID"), .value("\(projectID)"))
        if equipmentInfo == nil && field != .all && field != .pressure {
          input(.type(.hidden), .name("staticPressure"), .value("0.5"))
        }
        if field == .all || field == .heating {
          valueField(
            "Heating airflow (CFM)", name: "heatingCFM",
            value: equipmentInfo?.heatingCFM.map(String.init) ?? "", autofocus: true)
        }
        if field == .all || field == .cooling {
          valueField(
            "Cooling airflow (CFM)", name: "coolingCFM",
            value: equipmentInfo?.coolingCFM.map(String.init) ?? "", autofocus: field == .cooling)
        }
        if field == .all || field == .pressure {
          valueField(
            "External static pressure (in. w.c.)", name: "staticPressure",
            value: "\(equipmentInfo?.staticPressure ?? 0.5)", pressure: true,
            autofocus: field == .pressure)
        }
        p(.class("muted")) {
          "Use the blower's rated airflow at the selected external static pressure."
        }
        div(.class("flex justify-end gap-2")) {
          button(
            .type(.button), .class("btn btn-ghost"),
            .on(.click, "this.closest('dialog').close()")
          ) { "Cancel" }
          SubmitButton(title: field == .all ? "Save equipment" : "Save")
        }
      }
    }
  }

  private func valueField(
    _ labelText: String, name: String, value: String,
    pressure: Bool = false, autofocus: Bool
  ) -> some HTML & Sendable {
    label(.class("grid gap-2")) {
      span { labelText }
      input(
        .class("input w-full"), .name(name), .type(.number), .value(value),
        .min(pressure ? "0.01" : "1"), .step(pressure ? "0.01" : "1"), .required
      )
      .attributes(.max("0.99"), when: pressure)
      .attributes(.placeholder("e.g. 1000"), when: !pressure)
      .attributes(.autofocus, when: autofocus)
    }
  }
}
