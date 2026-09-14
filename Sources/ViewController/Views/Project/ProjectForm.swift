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
    ModalForm(id: Self.id, title: project == nil ? "New project" : "Project", dismiss: dismiss) {
      if project == nil {
        // Tab switching lives in project-import.js.
        div(
          .role("tablist"), .class("tabs tabs-box mb-5 grid grid-cols-2"),
          .init(name: "aria-label", value: "How to start the project"),
          .data("project-form-tabs", value: "")
        ) {
          Tab(
            title: "Import report", id: "projectImportTab", panel: "projectImportPanel",
            selected: true)
          Tab(
            title: "Enter manually", id: "projectManualTab", panel: "projectDetailsForm",
            selected: false)
        }
        div(
          .id("projectImportPanel"), .role("tabpanel"),
          .init(name: "aria-labelledby", value: "projectImportTab")
        ) {
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
            // Dialogs skip hidden autofocus targets, so this only applies when editing.
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
      .attributes(
        .role("tabpanel"), .init(name: "aria-labelledby", value: "projectManualTab"), .hidden,
        when: project == nil)
    }
  }

  private struct Tab: HTML, Sendable {
    let title: String
    let id: String
    let panel: String
    let selected: Bool

    var body: some HTML<HTMLTag.button> {
      button(
        .type(.button), .id(id), .role("tab"), .class(selected ? "tab tab-active" : "tab"),
        .init(name: "aria-controls", value: panel),
        .init(name: "aria-selected", value: String(selected)),
        .tabindex(selected ? 0 : -1)
      ) { title }
    }
  }
}
