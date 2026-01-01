import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ComponentLossForm: HTML, Sendable {
  var body: some HTML {
    div(
      .id("componentLossForm"),
      .class(
        """
        fixed top-40 left-[25vw] w-1/2 z-50 text-gray-800
        bg-gray-200 border border-gray-400 
        rounded-lg shadow-lg mx-10
        """
      )
    ) {
      h1(.class("text-2xl font-bold")) { "Component Loss" }
      form(.class("space-y-4 p-4")) {
        div {
          label(.for("name")) { "Name" }
          Input(id: "name", placeholder: "Name")
            .attributes(.type(.text), .required, .autofocus)
        }
        div {
          label(.for("value")) { "Value" }
          Input(id: "name", placeholder: "Pressure loss")
            .attributes(.type(.number), .min("0"), .max("1"), .step("0.1"), .required)
        }
        Row {
          div {}
          div {
            CancelButton()
              .attributes(
                .hx.get(route: .frictionRate(.form(.componentPressureLoss, dismiss: true))),
                .hx.target("#componentLossForm"),
                .hx.swap(.outerHTML)
              )
            SubmitButton()
          }
        }
      }
    }
  }
}
