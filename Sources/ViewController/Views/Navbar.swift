import Elementary
import ManualDCore
import Styleguide

/// Carries AuthClient's resolved decision into HTML streamed outside the request dependency scope.
public enum AdminViewValue {
  @TaskLocal public static var isAdministrator = false
}

struct Navbar: HTML, Sendable {
  var showFittingsButton = true
  var showDuctulatorButton = true
  var isLoggedIn = true

  var body: some HTML {
    nav(.class("app-navbar"), .init(name: "aria-label", value: "Main")) {
      a(.class("app-brand"), .href(route: isLoggedIn ? .project(.index) : .home)) {
        img(.src("/images/mand_logo_sm.webp"), .alt(""), .width(48), .height(48))
        span { "Duct Calc" }
      }
      div(.class("app-nav-actions")) {
        if showFittingsButton {
          a(.class("btn btn-outline"), .href(route: .fittingReference(.init()))) {
            "Fitting reference"
          }
        }
        if showDuctulatorButton {
          DuctulatorButton().attributes(.class("btn-outline"))
        }
        if isLoggedIn {
          details(.class("account-menu")) {
            summary(.class("btn")) {
              SVG(.circleUser)
              "Account"
            }
            ul(.class("menu bg-base-200 rounded-box shadow-lg")) {
              if AdminViewValue.isAdministrator {
                li { a(.href("/admin")) { "Admin" } }
              }
              li { a(.href(route: .user(.profile(.index)))) { "Profile" } }
              li { a(.href(route: .project(.index))) { "Projects" } }
              li {
                form(.action(SiteRoute.View.router.path(for: .user(.logout))), .method(.get)) {
                  button(.type(.submit)) { "Logout" }
                }
              }
            }
          }
        }
      }
    }
  }
}
