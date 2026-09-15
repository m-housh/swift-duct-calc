import Elementary
import ManualDCore
import Styleguide

/// Carries AuthClient's resolved decision into HTML streamed outside the request dependency scope.
public enum AdminViewValue {
  @TaskLocal public static var isAdministrator = false
}

struct Navbar: HTML, Sendable {
  @Environment(ShortcutViewValue.$bindings) private var bindings

  var showFittingsButton = true
  var showDuctulatorButton = true
  var isLoggedIn = true
  var shortcutsDialogID: String? = nil

  var body: some HTML {
    nav(.class("app-navbar"), .init(name: "aria-label", value: "Main")) {
      a(.class("app-brand"), .href(route: isLoggedIn ? .project(.index) : .home)) {
        DuctCalcWordmark(appTheme: true)
      }
      div(.class("app-nav-actions")) {
        if let shortcutsDialogID {
          button(
            .type(.button), .class("btn"),
            .init(name: "aria-label", value: "Keyboard shortcuts"),
            .title("Keyboard shortcuts, \(bindings.label(.help))"),
            .init(name: "aria-keyshortcuts", value: bindings[.help]),
            .init(name: "aria-haspopup", value: "dialog"),
            .init(name: "aria-controls", value: shortcutsDialogID),
            .showModal(id: shortcutsDialogID)
          ) { SVG(.keyboard) }
        }
        if showFittingsButton {
          a(
            .class("btn app-nav-link"), .href(route: .fittingReference(.init())),
            .target(.blank),
            .title("Fitting reference, \(bindings.label(.fittings))"),
            .init(name: "aria-keyshortcuts", value: bindings[.fittings])
          ) {
            span { "Fitting reference" }
          }
        }
        if showDuctulatorButton {
          DuctulatorButton().attributes(
            .class("app-nav-ductulator"), .title("Ductulator, \(bindings.label(.ductulator))"),
            .init(name: "aria-keyshortcuts", value: bindings[.ductulator])
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
                  .init(name: "aria-keyshortcuts", value: bindings[.profile])
                ) {
                  span { "Profile" }
                  span(.class("text-xs"), .init(name: "aria-hidden", value: "true")) {
                    "\(bindings.label(.profile))"
                  }
                }
              }
              li {
                a(
                  .href(route: .project(.index))
                ) {
                  span { "Projects" }
                  span(.class("text-xs"), .init(name: "aria-hidden", value: "true")) {
                    "\(bindings.label(.projects))"
                  }
                }.attributes(
                  .init(name: "aria-keyshortcuts", value: bindings[.projects]))
              }
              li { a(.href("/keybindings")) { "Keybindings" } }
              li { a(.href("/filters")) { "Filter library" } }
              li { a(.href("/filters?tab=preferences")) { "Design preferences" } }
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
