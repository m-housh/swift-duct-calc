import Elementary
import ElementaryHTMX

/// Owns multipart submission and transport errors shared by project and room imports.
struct ImportFileForm<Inner: HTML & Sendable>: HTML, Sendable {
  let action: String
  let inner: Inner

  init(action: String, @HTMLBuilder content: () -> Inner) {
    self.action = action
    self.inner = content()
  }

  var body: some HTML<HTMLTag.form> {
    form(
      .data("success-message", value: "Import complete."),
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
      inner
      p(.class("text-error mt-2"), .custom(name: "role", value: "alert"), .hidden) {}
    }
  }
}
