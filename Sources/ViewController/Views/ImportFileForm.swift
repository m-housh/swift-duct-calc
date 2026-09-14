import Elementary
import ElementaryHTMX
import Styleguide

/// Owns file choice, multipart submission, upload progress, and transport errors shared by
/// project and room imports. `file-import.js` moves the form between `empty`, `chosen`, and
/// `uploading`; forms add follow-up steps with `data-import-when` and their own states.
///
/// A form that accepts several formats can post each to its own route with a
/// `data-import-action-<extension>` attribute; `action` is used otherwise.
struct ImportFileForm<Inner: HTML & Sendable>: HTML, Sendable {
  let action: String
  let prompt: String
  let limits: String
  let accept: String
  let fileTypes: String
  let reading: String
  let inner: Inner

  /// - Parameters:
  ///   - prompt: The drop zone's heading.
  ///   - limits: Accepted formats and size, shown under the prompt.
  ///   - fileTypes: What to choose, completing "Choose a …" in labels and errors.
  ///   - reading: Shown once the upload finishes, while the server reads the file.
  init(
    action: String, prompt: String, limits: String, accept: String, fileTypes: String,
    reading: String, @HTMLBuilder content: () -> Inner
  ) {
    self.action = action
    self.prompt = prompt
    self.limits = limits
    self.accept = accept
    self.fileTypes = fileTypes
    self.reading = reading
    self.inner = content()
  }

  var body: some HTML<HTMLTag.form> {
    form(
      .data("success-message", value: "Import complete."),
      .data("file-import", value: ""),
      .data("file-types", value: fileTypes),
      .data("reading-label", value: reading),
      .hx.post(action),
      .hx.target("body"),
      .hx.swap(.outerHTML),
      .custom(name: "hx-encoding", value: "multipart/form-data"),
      .custom(name: "hx-disabled-elt", value: "find button"),
      .custom(
        name: "hx-on::response-error",
        value: """
          const error = this.querySelector('[role=alert]');
          error.textContent = event.detail.xhr.status === 413
            ? 'The file is too large. Choose a file smaller than 10 MB.'
            : 'The server could not complete the upload. Please try again.';
          error.hidden = false;
          """),
      .custom(
        name: "hx-on::send-error",
        value: """
          const error = this.querySelector('[role=alert]');
          error.textContent = 'The connection to the server was lost. Check your connection and try again.';
          error.hidden = false;
          """),
      .custom(
        name: "hx-on::before-request",
        value: "this.querySelector('[role=alert]').hidden = true;"),
      .custom(name: "enctype", value: "multipart/form-data")

    ) {
      label(
        .data("import-dropzone", value: ""),
        .class(
          """
          import-dropzone flex cursor-pointer flex-col items-center gap-2 rounded-box border-2
          border-dashed border-base-content/25 px-6 py-8 text-center transition-colors
          hover:border-primary hover:bg-primary/5 focus-within:outline-2
          focus-within:outline-offset-2 focus-within:outline-primary
          data-[dragover]:border-primary data-[dragover]:bg-primary/10
          """)
      ) {
        span(.class("grid size-14 place-items-center rounded-full bg-primary/10 text-primary")) {
          SVG(.upload)
        }
        span(.class("mt-1 text-base font-medium")) { prompt }
        span(.class("text-sm")) {
          "or "
          span(.class("link link-primary")) { "browse files" }
          " · \(limits)"
        }
        input(
          .type(.file), .name("file"), .custom(name: "accept", value: accept),
          .class("sr-only"), .custom(name: "aria-label", value: "Choose a \(fileTypes)"), .required)
      }
      div(
        .data("import-file", value: ""), .hidden,
        .class("flex items-center gap-3 rounded-box border border-base-content/15 bg-base-200 p-3")
      ) {
        span(
          .class("grid size-9 shrink-0 place-items-center rounded-md bg-primary/10 text-primary")
        ) {
          SVG(.fileText)
        }
        div(.class("min-w-0 flex-1")) {
          p(.class("truncate font-medium"), .data("import-file-name", value: "")) {}
          p(.class("text-sm"), .data("import-file-size", value: "")) {}
        }
        button(.type(.button), .class("btn btn-ghost btn-sm"), .data("import-replace", value: "")) {
          "Replace"
        }
        button(
          .type(.button), .class("btn btn-ghost btn-sm btn-square"),
          .custom(name: "aria-label", value: "Remove file"), .data("import-remove", value: "")
        ) { SVG(.close) }
      }
      div(.data("import-progress", value: ""), .class("mt-4"), .hidden) {
        p(
          .class("mb-1 flex justify-between text-sm"), .custom(name: "aria-live", value: "polite")
        ) {
          span(.data("import-progress-label", value: "")) { "Uploading…" }
          span(.data("import-progress-value", value: "")) {}
        }
        progress(
          .class("progress progress-primary w-full"), .init(name: "max", value: "100"),
          .init(name: "aria-label", value: "Import progress")
        ) {}
      }
      inner
      p(.class("text-error mt-2"), .custom(name: "role", value: "alert"), .hidden) {}
    }
  }
}
