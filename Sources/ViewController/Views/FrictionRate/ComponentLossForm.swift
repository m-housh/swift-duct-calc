import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ComponentLossForm: HTML, Sendable {
  let dismiss: Bool
  let projectID: Project.ID

  var body: some HTML {
    ModalForm(id: "componentLossForm", dismiss: dismiss) {
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
                .hx.get(
                  route: .project(
                    .detail(projectID, .frictionRate(.form(.componentPressureLoss, dismiss: true))))
                ),
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
