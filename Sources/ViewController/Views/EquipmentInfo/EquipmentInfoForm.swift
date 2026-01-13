import Elementary
import ManualDCore
import Styleguide

// TODO: Have form hold onto equipment info model to edit.
struct EquipmentInfoForm: HTML, Sendable {

  static let id = "equipmentForm"

  let dismiss: Bool
  let projectID: Project.ID
  let equipmentInfo: EquipmentInfo?

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
    ModalForm(id: Self.id, dismiss: dismiss) {
      h1(.class("text-3xl font-bold pb-6 ps-2")) { "Equipment Info" }
      form(
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
          .step("0.1"),
          .required
        )

        LabeledInput(
          "Heating CFM",
          .name("heatingCFM"),
          .type(.number),
          .value(equipmentInfo?.heatingCFM),
          .placeholder("1000"),
          .min("0"),
          .required,
          .autofocus
        )

        LabeledInput(
          "Cooling CFM",
          .name("coolingCFM"),
          .type(.number),
          .value(equipmentInfo?.coolingCFM),
          .placeholder("1000"),
          .min("0"),
          .required
        )

        SubmitButton(title: "Save")
          .attributes(.class("btn-block my-6"))
      }
    }
  }
}
