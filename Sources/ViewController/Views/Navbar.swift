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
  var shortcutsDialogID: String? = nil
  var showProjectsShortcut = true

  var body: some HTML {
    nav(.class("app-navbar"), .init(name: "aria-label", value: "Main")) {
      a(.class("app-brand"), .href(route: isLoggedIn ? .project(.index) : .home)) {
        img(.src("/images/mand_logo_sm.webp"), .alt(""), .width(48), .height(48))
        span { "Duct Calc" }
      }
      div(.class("app-nav-actions")) {
        if let shortcutsDialogID {
          button(
            .type(.button), .class("btn"),
            .init(name: "aria-label", value: "Keyboard shortcuts"),
            .init(name: "aria-haspopup", value: "dialog"),
            .init(name: "aria-controls", value: shortcutsDialogID),
            .showModal(id: shortcutsDialogID)
          ) { SVG(.keyboard) }
        }
        if showFittingsButton {
          a(
            .class("btn btn-outline btn-secondary"), .href(route: .fittingReference(.init())),
            .target(.blank),
            .title("Fitting reference, Ctrl+Alt+F"),
            .init(name: "aria-keyshortcuts", value: "Control+Alt+F")
          ) {
            span { "Fitting reference" }
          }
        }
        if showDuctulatorButton {
          DuctulatorButton().attributes(
            .class("btn-outline btn-primary"), .title("Ductulator, Ctrl+Alt+D"),
            .init(name: "aria-keyshortcuts", value: "Control+Alt+D")
          )
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
              li {
                a(
                  .href(route: .user(.profile(.index))),
                  .init(name: "aria-keyshortcuts", value: "Control+Alt+U")
                ) {
                  span { "Profile" }
                  span(.class("text-xs"), .init(name: "aria-hidden", value: "true")) {
                    "Ctrl+Alt+U"
                  }
                }
              }
              li {
                a(
                  .href(route: .project(.index))
                ) {
                  span { "Projects" }
                  if showProjectsShortcut {
                    span(.class("text-xs"), .init(name: "aria-hidden", value: "true")) {
                      "Ctrl+Alt+P"
                    }
                  }
                }.attributes(
                  .init(name: "aria-keyshortcuts", value: "Control+Alt+P"),
                  when: showProjectsShortcut)
              }
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
