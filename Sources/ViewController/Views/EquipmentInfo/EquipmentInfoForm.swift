import Elementary
import ManualDCore
import Styleguide

// TODO: Have form hold onto equipment info model to edit.
struct EquipmentInfoForm: HTML, Sendable {

  let dismiss: Bool
  let projectID: Project.ID
  let equipmentInfo: EquipmentInfo?

  var staticPressure: String {
    guard let staticPressure = equipmentInfo?.staticPressure else {
      return "0.5"
    }
    return "\(staticPressure)"
  }

  var heatingCFM: String {
    guard let heatingCFM = equipmentInfo?.heatingCFM else {
      return ""
    }
    return "\(heatingCFM)"
  }

  var coolingCFM: String {
    guard let heatingCFM = equipmentInfo?.heatingCFM else {
      return ""
    }
    return "\(heatingCFM)"
  }

  var body: some HTML {
    ModalForm(id: "equipmentForm", dismiss: dismiss) {
      h1(.class("text-3xl font-bold pb-6 ps-2")) { "Equipment Info" }
      form(
        .class("space-y-4 p-4"),
        equipmentInfo != nil
          ? .hx.patch(route: .project(.detail(projectID, .equipment(.index))))
          : .hx.post(route: .project(.detail(projectID, .equipment(.index)))),
        .hx.target("#equipmentInfo"),
        .hx.swap(.outerHTML)
      ) {
        input(.class("hidden"), .name("projectID"), .value("\(projectID)"))

        if let equipmentInfo {
          input(.class("hidden"), .name("id"), .value("\(equipmentInfo.id)"))
        }

        div {
          label(.for("staticPressure")) { "Static Pressure" }
          Input(id: "staticPressure", placeholder: "Static pressure")
            .attributes(
              .type(.number), .value(staticPressure), .min("0"), .max("1.0"), .step("0.1")
            )
        }
        div {
          label(.for("heatingCFM")) { "Heating CFM" }
          Input(id: "heatingCFM", placeholder: "CFM")
            .attributes(.type(.number), .min("0"), .value(heatingCFM))
        }
        div {
          label(.for("coolingCFM")) { "Cooling CFM" }
          Input(id: "coolingCFM", placeholder: "CFM")
            .attributes(.type(.number), .min("0"), .value(coolingCFM))
        }
        Row {
          div {}
          div(.class("space-x-4")) {
            CancelButton()
              .attributes(
                .hx.get(
                  route: .project(
                    .detail(projectID, .equipment(.form(dismiss: true)))
                  )
                ),
                .hx.target("#equipmentForm"),
                .hx.swap(.outerHTML)
              )
            SubmitButton(title: "Save")
          }
        }
      }
    }
  }
}
