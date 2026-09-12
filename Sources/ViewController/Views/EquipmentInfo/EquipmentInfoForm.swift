import Elementary
import ManualDCore
import Styleguide

struct EquipmentInfoForm: HTML, Sendable {

  static let id = "equipmentForm"

  @Environment(ProjectViewValue.$projectID) var projectID

  let dismiss: Bool
  let equipmentInfo: EquipmentInfo?
  var inline = false

  var staticPressure: String {
    guard let staticPressure = equipmentInfo?.staticPressure else {
      return "0.5"
    }
    return "\(staticPressure)"
  }

  var route: String {
    SiteRoute.View.router.path(
      for: .project(.detail(projectID, .equipment(.index)))
    )
    .appendingPath(equipmentInfo?.id)
  }

  var body: some HTML {
    if inline {
      fields
    } else {
      ModalForm(id: Self.id, title: "Equipment", dismiss: dismiss) { fields }
    }
  }

  var fields: some HTML & Sendable {
    form(
      .data("success-message", value: "Changes saved."),
      .class("grid grid-cols-1 gap-4"),
      equipmentInfo != nil
        ? .hx.patch(route)
        : .hx.post(route),
      .hx.target("body"),
      .hx.swap(.outerHTML)
    ) {
      input(.class("hidden"), .name("projectID"), .value("\(projectID)"))

      if let equipmentInfo {
        input(.class("hidden"), .name("id"), .value("\(equipmentInfo.id)"))
      }

      LabeledInput(
        "Static Pressure",
        .name("staticPressure"),
        .type(.number),
        .value(staticPressure),
        .min("0"),
        .max("1.0"),
        .step("0.01"),
        .required
      )

      LabeledInput(
        "Heating CFM",
        .name("heatingCFM"),
        .type(.number),
        .value(equipmentInfo?.heatingCFM),
        .placeholder("e.g. 1000"),
        .min("0"),
        .required,
        .autofocus
      )

      LabeledInput(
        "Cooling CFM",
        .name("coolingCFM"),
        .type(.number),
        .value(equipmentInfo?.coolingCFM),
        .placeholder("e.g. 1000"),
        .min("0"),
        .required
      )

      SubmitButton(title: "Save")
        .attributes(.class("btn-block my-6"))
    }
  }
}
