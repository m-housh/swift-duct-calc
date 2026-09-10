import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectForm: HTML, Sendable {

  static let id = "projectForm"

  let project: Project?
  let dismiss: Bool

  init(
    dismiss: Bool,
    project: Project? = nil
  ) {
    self.dismiss = dismiss
    self.project = project
  }

  var route: String {
    SiteRoute.View.router.path(for: .project(.index))
      .appendingPath(project?.id)
  }

  var body: some HTML {
    ModalForm(id: Self.id, title: "Project", dismiss: dismiss) {
      if project == nil {
        button(
          .type(.button), .class("btn btn-outline btn-block mb-4"),
          .custom(name: "aria-controls", value: "newProjectPDF"),
          .custom(name: "aria-expanded", value: "false"),
          .custom(
            name: "onclick",
            value: """
              const upload = document.getElementById('newProjectPDF');
              upload.hidden = !upload.hidden;
              document.getElementById('projectDetailsForm').hidden = !upload.hidden;
              this.textContent = upload.hidden ? 'Import from Cool Calc PDF' : 'Enter project manually';
              this.setAttribute('aria-expanded', String(!upload.hidden));
              """)
        ) { "Import from Cool Calc PDF" }
        div(.id("newProjectPDF"), .hidden) {
          ProjectPDFForm()
        }
      }
      div(.id("projectDetailsForm")) {
        form(
          .data("success-message", value: "Changes saved."),
          .class("grid grid-cols-1 gap-4"),
          project == nil
            ? .hx.post(route)
            : .hx.patch(route),
          .hx.target("body"),
          .hx.swap(.outerHTML)
        ) {
          if let project {
            input(.class("hidden"), .name("id"), .value("\(project.id)"))
          }

          LabeledInput(
            "Name",
            .name("name"),
            .type(.text),
            .value(project?.name),
            .placeholder("Project Name"),
            .required,
            .autofocus
          )

          LabeledInput(
            "Address",
            .name("streetAddress"),
            .type(.text),
            .value(project?.streetAddress),
            .placeholder("Street Address"),
            .required
          )

          LabeledInput(
            "City",
            .name("city"),
            .type(.text),
            .value(project?.city),
            .placeholder("City"),
            .required
          )

          LabeledInput(
            "State",
            .name("state"),
            .type(.text),
            .value(project?.state),
            .placeholder("State"),
            .required
          )

          LabeledInput(
            "Zip",
            .name("zipCode"),
            .type(.text),
            .value(project?.zipCode),
            .placeholder("Zip Code"),
            .required
          )

          SubmitButton()
            .attributes(.class("btn-block my-6"))
        }
      }
    }
  }

}
