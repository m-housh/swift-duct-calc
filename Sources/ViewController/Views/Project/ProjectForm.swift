import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectForm: HTML, Sendable {

  let project: Project?
  let dismiss: Bool

  init(
    dismiss: Bool,
    project: Project? = nil
  ) {
    self.dismiss = dismiss
    self.project = project
  }

  var body: some HTML {
    ModalForm(id: "projectForm", dismiss: dismiss) {
      h1(.class("text-3xl font-bold pb-6 ps-2")) { "Project" }
      form(
        .class("space-y-4 p-4"),
        project == nil
          ? .hx.post(route: .project(.index))
          : .hx.patch(route: .project(.index)),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {
        if let project {
          input(.class("hidden"), .name("id"), .value("\(project.id)"))
        }

        div {
          label(.for("name")) { "Name" }
          Input(id: "name", placeholder: "Name")
            .attributes(.type(.text), .required, .autofocus)
        }
        div {
          label(.for("streetAddress")) { "Address" }
          Input(id: "streetAddress", placeholder: "Street Address")
            .attributes(.type(.text), .required, .value(project?.streetAddress))
        }
        div {
          label(.for("city")) { "City" }
          Input(id: "city", placeholder: "City")
            .attributes(.type(.text), .required, .value(project?.city))
        }
        div {
          label(.for("state")) { "State" }
          Input(id: "state", placeholder: "State")
            .attributes(.type(.text), .required, .value(project?.state))
        }
        div {
          label(.for("zipCode")) { "Zip" }
          Input(id: "zipCode", placeholder: "Zip code")
            .attributes(.type(.text), .required, .value(project?.zipCode))
        }

        div(.class("flex justify-end space-x-6")) {
          CancelButton()
            .attributes(
              .hx.get(route: .project(.form(dismiss: true))),
              .hx.target("#projectForm"),
              .hx.swap(.outerHTML)
            )
          SubmitButton()
        }
      }
    }
  }

}
