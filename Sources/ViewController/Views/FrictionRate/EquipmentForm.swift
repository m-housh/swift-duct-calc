import Elementary
import ManualDCore
import Styleguide

// TODO: Have form hold onto equipment info model to edit.
struct EquipmentForm: HTML, Sendable {

  var body: some HTML {
    div(
      .id("equipmentForm"),
      .class(
        """
        fixed top-40 left-[25vw] w-1/2 z-50 text-gray-800
        bg-gray-200 border border-gray-400 
        rounded-lg shadow-lg mx-10
        """
      )
    ) {
      h1(.class("text-3xl font-bold pb-6 ps-2")) { "Equipment Info" }
      form(.class("space-y-4 p-4")) {
        div {
          label(.for("staticPressure")) { "Static Pressure" }
          Input(id: "staticPressure", placeholder: "Static pressure")
            .attributes(
              .type(.number), .value("0.5"), .min("0"), .max("1.0"), .step("0.1")
            )
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
            CancelButton()
              .attributes(
                .hx.get(route: .frictionRate(.form(.equipmentInfo, dismiss: true))),
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
