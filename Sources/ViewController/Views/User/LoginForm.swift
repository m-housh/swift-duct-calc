import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct LoginForm: HTML, Sendable {

  let style: Style
  let next: String?

  init(style: Style = .login, next: String? = nil) {
    self.style = style
    self.next = next
  }

  private var route: SiteRoute.View {
    if style == .login {
      return .login(.index(next: next))
    }
    return .signup(.index)
  }

  var body: some HTML {
    AuthLayout(
      id: "loginForm",
      title: style == .login ? "Welcome back" : "Create your account",
      subtitle: style == .login
        ? "Log in to continue your duct designs."
        : "Save your projects and keep your designs together.",
      step: style == .signup ? "Step 1 of 2 · Account" : nil
    ) {
      form(
        .method(.post),
        .hx.post(route: route),
        .hx.target("body"),
        .hx.swap(.outerHTML),
        .class("auth-form")
      ) {

        if let next {
          input(.type(.hidden), .name("next"), .value(next))
        }

        div(.class("auth-field")) {
          label(.for("email")) { "Email" }
          input(
            .class("input validator"), .type(.email), .required,
            .name("email"), .id("email"), .init(name: "autocomplete", value: "username"),
            .autofocus
          )
        }

        div(.class("auth-field")) {
          label(.for("password")) { "Password" }
          input(
            .class("input validator"), .type(.password), .required,
            .name("password"), .id("password"),
            .init(
              name: "autocomplete", value: style == .signup ? "new-password" : "current-password"),
          )
          .attributes(
            .pattern(.password), .minlength("8"),
            .init(name: "aria-describedby", value: "password-help"),
            when: style == .signup
          )
        }

        if style == .signup {
          div(.class("auth-field")) {
            label(.for("confirmPassword")) { "Confirm password" }
            input(
              .class("input validator"), .type(.password), .required,
              .pattern(.password), .minlength("8"),
              .name("confirmPassword"), .id("confirmPassword"),
              .init(name: "autocomplete", value: "new-password"),
              .init(name: "aria-describedby", value: "password-help"),
            )
          }
        }

        if style == .signup {
          p(.id("password-help"), .class("auth-password-help")) {
            "Use at least 8 characters, including an uppercase letter, a lowercase letter, and a number."
          }
        }

        button(.type(.submit), .class("btn btn-primary auth-submit")) { style.title }

        p(.class("auth-switch")) {
          span { style == .login ? "New to DuctCalc? " : "Already have an account? " }
          a(
            .href(route: style == .signup ? .login(.index(next: next)) : .signup(.index))
          ) {
            style == .login ? "Create an account" : "Log in"
          }
        }
      }
    }
  }
}

extension LoginForm {
  enum Style: Equatable, Sendable {
    case login
    case signup

    var title: String {
      switch self {
      case .login: return "Login"
      case .signup: return "Sign Up"
      }
    }
  }
}
