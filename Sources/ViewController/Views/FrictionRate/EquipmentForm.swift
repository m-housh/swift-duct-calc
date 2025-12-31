import Elementary
import ManualDCore
import Styleguide

struct EquipmentForm: HTML, Sendable {

  var body: some HTML {
    div(.id("equipmentForm")) {
      h1(.class("text-3xl font-bold pb-6")) { "Equipment Info" }
      form {
        div {
          label(.for("staticPressure")) { "Static Pressure" }
          Input(id: "staticPressure", placeholder: "Static pressure")
            .attributes(.type(.number), .value("0.5"), .min("0"), .max("1.0"), .step("0.1"))
        }
        div {
          label(.for("heatingCFM")) { "Heating CFM" }
          Input(id: "heatingCFM", placeholder: "CFM")
            .attributes(.type(.number), .min("0"))
        }
        div {
          label(.for("coolingCFM")) { "Cooling CFM" }
          Input(id: "coolingCFM", placeholder: "CFM")
            .attributes(.type(.number), .min("0"))
        }
        Row {
          div {}
          div(.class("space-x-4")) {
            SubmitButton(title: "Save")
          }
        }
      }
    }
  }
}
