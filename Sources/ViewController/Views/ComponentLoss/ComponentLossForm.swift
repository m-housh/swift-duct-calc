import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// FIX: The value field is sometimes wonky as far as what values it accepts.

struct ComponentLossForm: HTML, Sendable {

  static func id(_ componentLoss: ComponentPressureLoss? = nil) -> String {
    let base = "componentLossForm"
    guard let componentLoss else { return base }
    return "\(base)_\(componentLoss.id.idString)"
  }

  let dismiss: Bool
  let projectID: Project.ID
  let componentLoss: ComponentPressureLoss?

  var route: String {
    SiteRoute.View.router.path(
      for: .project(.detail(projectID, .componentLoss(.index)))
    )
    .appendingPath(componentLoss?.id)
  }

  var body: some HTML {
    ModalForm(id: Self.id(componentLoss), dismiss: dismiss) {
      h1(.class("text-2xl font-bold")) { "Component Loss" }
      form(
        .class("space-y-4 p-4"),
        componentLoss == nil
          ? .hx.post(route)
          : .hx.patch(route),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {

        if let componentLoss {
          input(.class("hidden"), .name("id"), .value("\(componentLoss.id)"))
        }

        input(.class("hidden"), .name("projectID"), .value("\(projectID)"))

        div {
          label(.for("name")) { "Name" }
          Input(id: "name", placeholder: "Name")
            .attributes(.type(.text), .required, .autofocus, .value(componentLoss?.name))
        }
        div {
          label(.for("value")) { "Value" }
          Input(id: "value", placeholder: "Pressure loss")
            .attributes(
              .type(.number), .min("0.03"), .max("1.0"), .step("0.01"), .required,
              .value(componentLoss?.value)
            )
        }

        SubmitButton()
          .attributes(.class("btn-block"))
      }
    }
  }
}
