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
    ModalForm(id: Self.id(profile), title: "Profile", dismiss: dismiss) {


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

        label(.class("select w-full")) {
          span(.class("label")) { "Theme" }
          select(.name("theme")) {
            option(.value("default")) { "System default" }
              .attributes(.selected, when: profile?.theme == nil || profile?.theme == .default)
            optgroup(.label("Light")) {
              for theme in Theme.lightThemes {
                option(.value(theme.rawValue)) { theme.rawValue.capitalized }
                  .attributes(.selected, when: profile?.theme == theme)
              }
            }
            optgroup(.label("Dark")) {
              for theme in Theme.darkThemes {
                option(.value(theme.rawValue)) { theme.rawValue.capitalized }
                  .attributes(.selected, when: profile?.theme == theme)
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
