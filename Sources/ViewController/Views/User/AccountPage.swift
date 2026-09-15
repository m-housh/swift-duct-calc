import Elementary
import Styleguide

/// Account pages share navigation; project-scoped template flows keep their project context.
struct AccountPage<Inner: HTML & Sendable>: HTML, Sendable {
  enum Section: String, CaseIterable {
    case profile = "Profile"
    case keybindings = "Keybindings"
    case templates = "Path templates"
    case filters = "Filter library"
    case preferences = "Design preferences"

    var path: String {
      switch self {
      case .profile: "/profile"
      case .keybindings: "/keybindings"
      case .templates: "/path-templates"
      case .filters: "/filters"
      case .preferences: "/filters?tab=preferences"
      }
    }
  }

  let selected: Section
  let inner: Inner

  init(selected: Section, @HTMLBuilder content: () -> Inner) {
    self.selected = selected
    self.inner = content()
  }

  var body: some HTML {
    div(.class("account-workspace")) {
      link(.rel(.stylesheet), .href("/css/account.css?v=keybindings-2"))
      Navbar()
      div(.class("account-layout")) {
        aside(.class("account-sidebar")) {
          h2 { "Account" }
          nav(.init(name: "aria-label", value: "Account sections")) {
            for section in Section.allCases {
              if section == .templates {
                span(.class("account-nav-group"), .init(name: "aria-hidden", value: "true")) {
                  "Libraries & preferences"
                }
              }
              a(.href(section.path)) { section.rawValue }
                .attributes(.init(name: "aria-current", value: "page"), when: section == selected)
            }
          }
        }
        div(.class("account-content")) { inner }
      }
    }
  }
}
