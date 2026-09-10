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
    ModalForm(id: "loginForm", title: style.title, dismiss: false) {
      Row {
        a(
          .class("btn btn-link"),
          .href(route: .privacyPolicy),
          .target(.blank)
        ) {
          "Privacy Policy"
        }
      }

      form(
        .method(.post),
        .class("space-y-4")
      ) {

        if let next {
          input(.class("hidden"), .name("next"), .value(next))
        }

        div {
          label(.class("input validator w-full")) {
            span(.class("label")) { "Email" }
            input(
              .type(.email), .placeholder("Email"), .required,
              .name("email"), .id("email"), .init(name: "autocomplete", value: "username"),
              .autofocus
            )
          }
          div(.class("validator-hint hidden")) { "Enter valid email address." }
        }

        div {
          label(.class("input validator w-full")) {
            span(.class("label")) { "Password" }
            input(
              .type(.password), .placeholder("Password"), .required,
              .pattern(.password), .minlength("8"),
              .name("password"), .id("password"),
              .init(
                name: "autocomplete", value: style == .signup ? "new-password" : "current-password"),
              .init(name: "aria-describedby", value: "password-help"),
            )
          }
        }

        if style == .signup {
          div {
            label(.class("input validator w-full")) {
              span(.class("label")) { "Confirm password" }
              input(
                .type(.password), .placeholder("Confirm Password"), .required,
                .pattern(.password), .minlength("8"),
                .name("confirmPassword"), .id("confirmPassword"),
                .init(name: "autocomplete", value: "new-password"),
                .init(name: "aria-describedby", value: "password-help"),
              )
            }
          }
        }

        p(.id("password-help"), .class("text-sm")) {
          "Use at least 8 characters, including an uppercase letter, a lowercase letter, and a number."
        }

        div(.class("flex")) {
          button(.class("btn btn-secondary mt-4 w-full")) { style.title }
        }

        div(.class("flex justify-center")) {
          a(
            .class("btn btn-link"),
            .href(route: style == .signup ? .login(.index(next: next)) : .signup(.index))
          ) {
            style == .login ? "Sign Up" : "Login"
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
