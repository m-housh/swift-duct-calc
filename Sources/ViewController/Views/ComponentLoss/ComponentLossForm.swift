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
    ModalForm(id: Self.id(componentLoss), title: "Component Loss", dismiss: dismiss) {
      form(
        .data("success-message", value: "Changes saved."),
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

        LabeledInput(
          "Component",
          .name("name"),
          .type(.text),
          .value(componentLoss?.name),
          .placeholder("e.g. Filter"),
          .init(name: "autocomplete", value: "off"),
          .data("1p-ignore", value: "true"),
          .data("bwignore", value: "true"),
          .data("lpignore", value: "true"),
          .data("protonpass-ignore", value: "true"),
          .required,
          .autofocus
        )

        LabeledInput(
          "Value",
          .name("value"),
          .type(.number),
          .value(componentLoss?.value),
          .placeholder("0.2"),
          .min("0.01"),
          .max("1.0"),
          .step("0.01"),
          .required
        )

        SubmitButton()
          .attributes(.class("btn-block"))
      }
    }
  }
}
