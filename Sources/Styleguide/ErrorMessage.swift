import Elementary
import ManualDCore

public struct ErrorMessage: HTML, Sendable {
  let error: PresentationError

  public init(_ error: PresentationError) { self.error = error }

  public var body: some HTML {
    div(
      .role("alert"), .tabindex(-1), .class("error-message"), .data("error-message", value: "true")
    ) {
      h2(.class("font-bold text-error")) { error.title }
      p { error.message }
      if !error.fields.isEmpty {
        ul {
          for field in error.fields { li { field.message } }
        }
      }
      if let reference = error.reference {
        p(.class("text-sm")) { "Error reference: \(reference)" }
      }
      for action in error.actions {
        a(.class("link"), .href(action.href), .target(.blank), .rel("noopener")) { action.label }
      }
    }
  }
}
