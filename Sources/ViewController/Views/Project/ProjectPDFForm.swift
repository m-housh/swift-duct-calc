import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectPDFForm: HTML {
  var body: some HTML {
    p(.class("mb-4")) {
      "Create a project using the name, address, sensible heat ratio, and room loads from a Cool Calc MJ8 report. You can edit them after import."
    }
    p(.class("text-sm mb-4")) { "Maximum 10 MB and 200 pages." }
    ImportFileForm(
      action: SiteRoute.View.router.path(for: .project(.index)).appendingPath("import/pdf")
    ) {
      input(.type(.hidden), .name("confirmDuplicate"), .value("false"))
      input(
        .type(.file), .name("file"), .accept(".pdf,application/pdf"),
        .custom(name: "aria-label", value: "Cool Calc PDF"), .required,
        .custom(
          name: "onchange",
          value: """
            this.form.elements.confirmDuplicate.value = 'false';
            this.form.querySelector('[data-duplicate-warning]').hidden = true;
            this.form.querySelector('[data-import-submit]').hidden = false;
            """))
      div(.custom(name: "data-import-submit", value: "")) {
        SubmitButton(title: "Create project from PDF")
          .attributes(.class("btn-block mt-6"))
      }
      div(
        .custom(name: "data-duplicate-warning", value: ""), .class("mt-6"), .hidden,
        .custom(name: "aria-live", value: "polite")
      ) {
        div(.custom(name: "data-duplicate-details", value: "")) {}
        div(.class("flex gap-4 mt-6")) {
          button(
            .type(.button), .class("btn btn-outline"),
            .custom(
              name: "onclick",
              value: """
                this.form.elements.confirmDuplicate.value = 'false';
                this.form.querySelector('[data-duplicate-warning]').hidden = true;
                this.form.querySelector('[data-import-submit]').hidden = false;
                this.form.querySelector('input[type=file]').focus();
                """)
          ) { "Cancel" }
          SubmitButton(title: "Create another project")
            .attributes(
              .custom(name: "onclick", value: "this.form.elements.confirmDuplicate.value = 'true';")
            )
        }
      }
      p(.class("htmx-indicator text-sm mt-2")) { "Reading project and room loads…" }
    }
    .attributes(
      .custom(
        name: "hx-on::before-on-load",
        value: """
          const response = new DOMParser().parseFromString(event.detail.xhr.responseText, 'text/html');
          const conflict = response.querySelector('[data-project-import-conflict]');
          if (conflict) {
            event.preventDefault();
            const warning = this.querySelector('[data-duplicate-warning]');
            warning.querySelector('[data-duplicate-details]').replaceChildren(conflict);
            warning.hidden = false;
            this.querySelector('[data-import-submit]').hidden = true;
            warning.querySelector('button').focus();
          }
          """),
      .custom(
        name: "hx-on::after-request", value: "this.elements.confirmDuplicate.value = 'false';")
    )
  }
}
