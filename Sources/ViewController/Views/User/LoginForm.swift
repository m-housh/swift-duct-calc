import Elementary
import ElementaryHTMX
import Styleguide

struct LoginForm: HTML, Sendable {

  let style: Style

  init(style: Style = .login) {
    self.style = style
  }

  var body: some HTML {
    form {
      fieldset(.class("fieldset bg-base-200 border-base-300 rounded-box w-xl border p-4")) {
        legend(.class("fieldset-legend")) { style.title }

        if style == .signup {
          label(.class("input validator w-full")) {
            SVG(.user)
            input(
              .type(.text), .required, .placeholder("Username"),
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
            .type(.email), .placeholder("Email"), .required
          )
        }
        div(.class("validator-hint hidden")) { "Enter valid email address." }

        label(.class("input validator w-full")) {
          SVG(.key)
          input(
            .type(.password), .placeholder("Password"), .required,
            .pattern(.password), .minlength("8")
          )
        }

        if style == .signup {
          label(.class("input validator w-full")) {
            SVG(.key)
            input(
              .type(.password), .placeholder("Confirm Password"), .required,
              .pattern(.password), .minlength("8")
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

        button(.class("btn btn-neutral mt-4")) { style.title }
      }
    }
    // div(.class("flex items-center justify-center")) {
    //   div(.class("w-full mx-auto")) {
    //     h1(.class("text-2xl font-bold")) { style.title }
    //     form(
    //       .class("w-full h-screen")
    //     ) {
    //       fieldset(.class("fieldset w-full")) {
    //         legend(.class("fieldset-legend")) { "Email" }
    //         label(.class("input validator")) {
    //           SVG(.email)
    //           input(
    //             .type(.email), .placeholder("mail@site.com"), .required,
    //             .autofocus
    //           )
    //         }
    //         div(.class("validator-hint hidden")) { "Enter valid email address." }
    //       }
    //
    //       if style == .signup {
    //         fieldset(.class("fieldset")) {
    //           legend(.class("fieldset-legend")) { "Name" }
    //           label(.class("input validator")) {
    //             input(
    //               .type(.text), .placeholder("Username"), .required,
    //               .init(name: "pattern", value: "[A-Za-z][A-Za-z0-9\\-]*"),
    //               .init(name: "minlength", value: "3")
    //             )
    //           }
    //           div(.class("validator-hint hidden")) { "Enter valid email address." }
    //         }
    //       }
    //
    //       fieldset(.class("fieldset")) {
    //         legend(.class("fieldset-legend")) { "Password" }
    //         label(.class("input validator")) {
    //           SVG(.key)
    //           input(
    //             .type(.password), .placeholder("Password"), .required,
    //             .init(name: "pattern", value: "(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).{8,}"),
    //             .init(name: "minlength", value: "8")
    //           )
    //         }
    //         if style == .signup {
    //           label(.class("input validator")) {
    //             SVG(.key)
    //             input(
    //               .type(.password), .placeholder("Confirm Password"), .required,
    //               .init(name: "pattern", value: "(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).{8,}"),
    //               .init(name: "minlength", value: "8")
    //             )
    //           }
    //         }
    //         div(.class("validator-hint hidden")) {
    //           p {
    //             "Must be more than 8 characters, including"
    //             br()
    //             "At least one number"
    //             br()
    //             "At least one lowercase letter"
    //             br()
    //             "At least one uppercase letter"
    //           }
    //         }
    //       }
    //
    //       SubmitButton(title: style.title)
    //     }
    //   }
    // }
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
