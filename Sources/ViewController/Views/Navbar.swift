import Elementary
import ManualDCore
import Styleguide

/// Carries AuthClient's resolved decision into HTML streamed outside the request dependency scope.
public enum AdminViewValue {
  @TaskLocal public static var isAdministrator = false
}

struct Navbar: HTML, Sendable {
  let showFittingsButton: Bool
  let showDuctulatorButton: Bool
  let showSidebarToggle: Bool
  let isLoggedIn: Bool

  init(
    showFittingsButton: Bool = true,
    showDuctulatorButton: Bool = true,
    showSidebarToggle: Bool,
    isLoggedIn: Bool = true
  ) {
    self.showFittingsButton = showFittingsButton
    self.showDuctulatorButton = showDuctulatorButton
    self.showSidebarToggle = showSidebarToggle
    self.isLoggedIn = isLoggedIn
  }

  var homeRoute: SiteRoute.View {
    if isLoggedIn {
      return .project(.index)
    }
    return .home
  }

  private var isAdministrator: Bool {
    AdminViewValue.isAdministrator
  }

  var body: some HTML<HTMLTag.nav> {
    nav(
      .class(
        """
        navbar flex-wrap w-full bg-base-300 text-base-content shadow-sm mb-4
        """
      )
    ) {
      div(.class("flex flex-1 space-x-4 items-center")) {
        if showSidebarToggle {
          label(
            .for("my-drawer-1"),
            .class("size-7"),
            .init(name: "aria-label", value: "open / close sidebar")
          ) {
            SVG(.sidebarToggle)
          }
          .navButton()
          .tooltip("Open / close sidebar", position: .right)
        }

        a(
          .class("flex w-fit h-fit text-2xl items-end px-4 py-2"),
          .href(route: homeRoute)
        ) {
          img(
            .src("/images/mand_logo_sm.webp"),
          )
          span { "Duct Calc" }
        }
        .navButton()
        .tooltip(isLoggedIn ? "Projects, Ctrl+Alt+P" : "Home", position: .right)

        if showSidebarToggle {
          button(
            .type(.button), .class("size-7"),
            .init(name: "aria-label", value: "Keyboard shortcuts"),
            .init(name: "aria-haspopup", value: "dialog"),
            .init(name: "aria-controls", value: ProjectShortcutsDialog.id),
            .showModal(id: ProjectShortcutsDialog.id)
          ) { SVG(.keyboard) }
          .navButton()
          .tooltip("Keyboard shortcuts", position: .bottom)
        }
      }

      div(.class("flex-none")) {
        div(.class("flex items-end space-x-4")) {

          if showFittingsButton {
            a(
              .class("btn btn-outline btn-secondary"), .href(route: .fittingReference(.init())),
              .target(.blank),
              .init(name: "aria-keyshortcuts", value: "Control+Alt+F"),
              .init(name: "aria-describedby", value: "fitting-reference-help")
            ) {
              "Fitting reference"
            }
            .tooltip("Fitting reference, Ctrl+Alt+F", position: .bottom)
            span(.id("fitting-reference-help"), .class("sr-only")) { "Browse fitting references" }
          }

          if showDuctulatorButton {
            DuctulatorButton()
              .attributes(
                .class("btn-outline btn-primary"),
                .init(name: "aria-keyshortcuts", value: "Control+Alt+D")
              )
              .tooltip("Ductulator, Ctrl+Alt+D", position: .bottom)
          }

          if isLoggedIn {
            div(.class("dropdown dropdown-end dropdown-hover")) {
              div(.class("btn m-1"), .tabindex(0), .role("button")) {
                SVG(.circleUser)
              }
              .navButton()
              ul(
                .tabindex(-1),
                .class("dropdown-content menu bg-base-200 rounded-box z-1 w-52 py-2 shadow-sm")
              ) {
                if isAdministrator {
                  li { a(.href("/admin")) { "Admin" } }
                }
                li {
                  a(
                    .href(route: .user(.profile(.index))),
                    .class("flex justify-between"),
                    .init(name: "aria-keyshortcuts", value: "Control+Alt+U")
                  ) {
                    span { "Profile" }
                    span(.class("text-xs opacity-70")) { "Ctrl+Alt+U" }
                  }
                }
                li {
                  a(
                    .href(route: .project(.index)),
                    .class("flex justify-between"),
                    .init(name: "aria-keyshortcuts", value: "Control+Alt+P"),
                    .hx.get(route: .project(.index)),
                    .hx.pushURL(true),
                    .hx.target("body"),
                    .hx.swap(.outerHTML)
                  ) {
                    span { "Projects" }
                    span(.class("text-xs opacity-70")) { "Ctrl+Alt+P" }
                  }
                }
                li {
                  a(
                    .hx.get(route: .user(.logout)),
                    .hx.pushURL("/login"),
                    .hx.target("body"),
                    .hx.swap(.outerHTML)
                  ) { "Logout" }
                }
              }
            }
          }
        }
      }
    }
  }
}

extension HTML where Tag: HTMLTrait.Attributes.Global {
  func navButton() -> _AttributedElement<Self> {
    attributes(
      .class("btn btn-square btn-ghost hover:bg-neutral hover:text-white")
    )
  }
}
