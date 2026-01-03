import Elementary
import ElementaryHTMX
import Styleguide

struct LoginForm: HTML, Sendable {

  let style: Style

  init(style: Style = .login) {
    self.style = style
  }

  var body: some HTML {
    div(
      .id("loginForm"),
      .class("flex items-center justify-center")
    ) {
      form(
        .method(.post)
      ) {
        fieldset(.class("fieldset bg-base-200 border-base-300 rounded-box w-xl border p-4")) {
          legend(.class("fieldset-legend")) { style.title }

          if style == .signup {
            label(.class("input validator w-full")) {
              SVG(.user)
              input(
                .type(.text), .required, .placeholder("Username"),
                .name("username"), .id("username"),
                .minlength("3"), .pattern(.username)
              )
            }
            div(.class("validator-hint hidden")) {
              "Enter valid username"
              br()
              "Must be at least 3 characters"
            }
          }

          label(.class("input validator w-full")) {
            SVG(.email)
            input(
              .type(.email), .placeholder("Email"), .required,
              .name("email"), .id("email"),
            )
          }
          div(.class("validator-hint hidden")) { "Enter valid email address." }

          label(.class("input validator w-full")) {
            SVG(.key)
            input(
              .type(.password), .placeholder("Password"), .required,
              .pattern(.password), .minlength("8"),
              .name("password"), .id("password"),
            )
          }

          if style == .signup {
            label(.class("input validator w-full")) {
              SVG(.key)
              input(
                .type(.password), .placeholder("Confirm Password"), .required,
                .pattern(.password), .minlength("8"),
                .name("confirmPassword"), .id("confirmPassword"),
              )
            }
          }

          div(.class("validator-hint hidden")) {
            p {
              "Must be more than 8 characters, including"
              br()
              "At least one number"
              br()
              "At least one lowercase letter"
              br()
              "At least one uppercase letter"
            }
          }

          button(.class("btn btn-secondary mt-4")) { style.title }
          a(
            .class("btn btn-link mt-4"),
            .href(route: style == .signup ? .login(.index) : .signup(.index))
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
