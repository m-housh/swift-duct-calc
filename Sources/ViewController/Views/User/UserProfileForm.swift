import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct UserProfileForm: HTML, Sendable {
  let userID: User.ID
  var profile: User.Profile? = nil
  var signup = false

  private var route: String {
    if signup {
      return SiteRoute.View.router.path(for: .signup(.index)).appendingPath("profile")
    }
    return SiteRoute.View.router.path(for: .user(.profile(.index))).appendingPath(profile?.id)
  }

  var body: some HTML {
    if signup {
      link(.rel(.stylesheet), .href("/css/account.css?v=1"))
      ModalForm(id: "userProfileForm", title: "Profile", dismiss: false) { profileForm }
    } else {
      profileForm
    }
  }

  private var profileForm: some HTML & Sendable {
    form(
      .id("profile-form"), .class("account-profile-form"),
      .data("success-message", value: "Changes saved."),
      profile == nil ? .hx.post(route) : .hx.patch(route),
      .hx.target("body"), .hx.swap(.outerHTML)
    ) {
      div(.class("account-form-heading")) {
        h2 { "Personal & company details" }
        p { "Your name and company address." }
      }
      if let profile { input(.type(.hidden), .name("id"), .value(profile.id)) }
      input(.type(.hidden), .name("userID"), .value(userID))
      div(.class("account-form-content")) {
        div(.class("account-profile-fields")) {
          field(
            "First name", name: "firstName", value: profile?.firstName, autocomplete: "given-name")
          field(
            "Last name", name: "lastName", value: profile?.lastName, autocomplete: "family-name")
          field(
            "Company", name: "companyName", value: profile?.companyName,
            autocomplete: "organization"
          )
          .attributes(.class("account-field-wide"))
          field(
            "Street address", name: "streetAddress", value: profile?.streetAddress,
            autocomplete: "street-address"
          )
          .attributes(.class("account-field-wide"))
          div(.class("account-address-fields account-field-wide")) {
            field("City", name: "city", value: profile?.city, autocomplete: "address-level2")
            field("State", name: "state", value: profile?.state, autocomplete: "address-level1")
            field("ZIP code", name: "zipCode", value: profile?.zipCode, autocomplete: "postal-code")
          }
        }
        div(.class("account-appearance")) {
          h2 { "Appearance" }
          p { "Choose the theme used throughout DuctCalc." }
          label(.class("account-profile-field")) {
            span { "Theme" }
            select(.name("theme"), .class("select")) {
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
        }
      }
      div(.class("account-form-actions")) {
        if !signup { button(.type(.reset), .class("btn btn-ghost")) { "Reset" } }
        button(.type(.submit), .class("btn btn-primary")) { signup ? "Continue" : "Save changes" }
      }
    }
    .attributes(.hx.pushURL("/projects"), when: signup)
  }

  private func field(
    _ title: String, name: String, value: String?, autocomplete: String
  ) -> some HTML<HTMLTag.label> & Sendable {
    label(.class("account-profile-field")) {
      span { title }
      input(
        .class("input"), .name(name), .value(value), .required,
        .init(name: "autocomplete", value: autocomplete)
      )
    }
  }
}
