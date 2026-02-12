import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct UserProfileForm: HTML, Sendable {

  static func id(_ profile: User.Profile?) -> String {
    let base = "userProfileForm"
    guard let profile else { return base }
    return "\(base)_\(profile.id.idString)"
  }

  let userID: User.ID
  let profile: User.Profile?
  let dismiss: Bool
  let signup: Bool

  init(
    userID: User.ID,
    profile: User.Profile? = nil,
    dismiss: Bool,
    signup: Bool = false
  ) {
    self.userID = userID
    self.profile = profile
    self.dismiss = dismiss
    self.signup = signup
  }

  var route: String {
    guard !signup else {
      return SiteRoute.View.router.path(for: .signup(.index))
        .appendingPath("profile")
    }
    return SiteRoute.View.router.path(for: .user(.profile(.index)))
      .appendingPath(profile?.id)
  }

  var body: some HTML {
    ModalForm(id: Self.id(profile), closeButton: dismiss, dismiss: dismiss) {

      h1(.class("text-xl font-bold pb-6")) { "Profile" }

      form(
        .class("grid grid-cols-1 gap-4 p-4"),
        profile == nil
          ? .hx.post(route)
          : .hx.patch(route),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {
        if let profile {
          input(.class("hidden"), .name("id"), .value(profile.id))
        }
        input(.class("hidden"), .name("userID"), .value(userID))

        label(.class("input w-full")) {
          span(.class("label")) { "First Name" }
          input(.name("firstName"), .value(profile?.firstName), .required, .autofocus)
        }

        label(.class("input w-full")) {
          span(.class("label")) { "Last Name" }
          input(.name("lastName"), .value(profile?.lastName), .required)
        }

        label(.class("input w-full")) {
          span(.class("label")) { "Company" }
          input(.name("companyName"), .value(profile?.companyName), .required)
        }

        label(.class("input w-full")) {
          span(.class("label")) { "Address" }
          input(.name("streetAddress"), .value(profile?.streetAddress), .required)
        }

        label(.class("input w-full")) {
          span(.class("label")) { "City" }
          input(.name("city"), .value(profile?.city), .required)
        }

        label(.class("input w-full")) {
          span(.class("label")) { "State" }
          input(.name("state"), .value(profile?.state), .required)
        }

        label(.class("input w-full")) {
          span(.class("label")) { "Zip" }
          input(.name("zipCode"), .value(profile?.zipCode), .required)
        }

        div(.class("dropdown dropdown-top")) {
          div(.class("input btn m-1 w-full"), .tabindex(0), .role(.init(rawValue: "button"))) {
            "Theme"
            SVG(.chevronDown)
          }
          ul(
            .tabindex(-1),
            .class("dropdown-content bg-base-300 rounded-box z-1 p-2 shadow-2xl")
          ) {
            li {
              input(
                .type(.radio),
                .name("theme"),
                .class("theme-controller w-full btn btn-sm btn-block btn-ghost justify-start"),
                .init(name: "aria-label", value: "Default"),
                .value("default")
              )
              .attributes(.checked, when: profile?.theme == .default)
            }
            li {
              span(.class("text-sm font-bold text-gray-400")) {
                "Light"
              }
            }
            for theme in Theme.lightThemes {
              li {
                input(
                  .type(.radio),
                  .name("theme"),
                  .class("theme-controller w-full btn btn-sm btn-block btn-ghost justify-start"),
                  .init(name: "aria-label", value: "\(theme.rawValue.capitalized)"),
                  .value(theme.rawValue)
                )
                .attributes(.checked, when: profile?.theme == theme)
              }
            }
            li {
              span(.class("text-sm font-bold text-gray-400")) {
                "Dark"
              }
            }
            for theme in Theme.darkThemes {
              li {
                input(
                  .type(.radio),
                  .name("theme"),
                  .class("theme-controller w-full btn btn-sm btn-block btn-ghost justify-start"),
                  .init(name: "aria-label", value: "\(theme.rawValue.capitalized)"),
                  .value(theme.rawValue)
                )
                .attributes(.checked, when: profile?.theme == theme)
              }
            }
          }
        }

        SubmitButton()
          .attributes(.class("btn-block"))

      }
      .attributes(
        .hx.pushURL("/projects"),
        when: signup == true
      )
    }
  }
}
