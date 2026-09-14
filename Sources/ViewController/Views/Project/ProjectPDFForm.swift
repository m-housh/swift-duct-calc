import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

/// Creates a project from a report. `project-import.js` adds the server's follow-up questions,
/// a missing ZIP code or a possible duplicate, to the shared import steps.
struct ProjectPDFForm: HTML {
  var body: some HTML {
    p(.class("mb-4")) {
      "Creates the project with its name, address, sensible heat ratio, and room loads from a Cool Calc MJ8 report. You can edit them after import."
    }
    ImportFileForm(
      action: SiteRoute.View.router.path(for: .project(.index)).appendingPath("import/pdf"),
      prompt: "Drop your Cool Calc MJ8 report",
      limits: "PDF up to 10 MB and 200 pages",
      accept: ".pdf,application/pdf",
      fileTypes: "Cool Calc MJ8 report PDF",
      reading: "Reading project and room loads…"
    ) {
      input(.type(.hidden), .name("confirmDuplicate"), .value("false"))
      div(.data("import-when", value: "missing-zip"), .hidden) {
        p(
          .class("mt-4 mb-4"), .data("zip-message", value: ""),
          .custom(name: "aria-live", value: "polite")
        ) {}
        LabeledInput(
          "ZIP code", .name("zipCode"), .type(.text), .placeholder("ZIP code"),
          .pattern(value: "[0-9]{5}(-[0-9]{4})?"), .disabled)
      }
      div(
        .data("import-when", value: "duplicate"), .class("mt-4"), .hidden,
        .custom(name: "aria-live", value: "polite")
      ) {
        div(.data("duplicate-details", value: "")) {}
        LabeledInput("Name", .name("name"), .type(.text), .placeholder("Project name"), .disabled)
          .attributes(.class("mt-4"))
        div(.class("mt-6 grid grid-cols-2 gap-2")) {
          button(.type(.button), .class("btn btn-outline"), .data("import-cancel", value: "")) {
            "Cancel"
          }
          SubmitButton(title: "Create project")
        }
      }
      div(
        .data("import-submit", value: ""), .data("import-when", value: "chosen missing-zip"),
        .hidden
      ) {
        SubmitButton(title: "Create project")
          .attributes(.class("btn-block mt-4"))
      }
    }
    .attributes(.data("project-import", value: ""))
  }
}
