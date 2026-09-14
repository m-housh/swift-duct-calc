import Elementary
import ManualDCore

/// Page layout shared by sign-in and the two account setup steps.
public struct AuthLayout<Inner: HTML & Sendable>: HTML, Sendable {
  let id: String
  let title: String
  let subtitle: String
  let step: String?
  let inner: Inner

  public init(
    id: String, title: String, subtitle: String, step: String? = nil,
    @HTMLBuilder content: () -> Inner
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.step = step
    self.inner = content()
  }

  public var body: some HTML {
    link(.rel(.stylesheet), .href("/css/auth.css?v=1"))
    div(.class("auth-layout")) {
      header(.class("auth-header")) {
        a(.class("auth-brand"), .href(route: .home)) { DuctCalcWordmark() }
        a(.href(route: .home)) { "Back to home" }
      }
      section(
        .id(id), .class("auth-content"), .init(name: "aria-labelledby", value: "\(id)-title")
      ) {
        div(.class("auth-heading")) {
          if let step { p(.class("auth-step")) { step } }
          h1(.id("\(id)-title")) { title }
          p { subtitle }
        }
        inner
      }
      footer(.class("auth-footer")) {
        a(.href(route: .privacyPolicy), .target(.blank)) { "Privacy Policy" }
        a(.href("mailto:support@ductcalc.pro")) { "Contact Michael" }
      }
    }
  }
}
