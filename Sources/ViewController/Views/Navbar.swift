import Elementary
import ManualDCore
import Styleguide

struct Navbar: HTML, Sendable {
  let showSidebarToggle: Bool
  let isLoggedIn: Bool

  init(
    showSidebarToggle: Bool,
    isLoggedIn: Bool = true
  ) {
    self.showSidebarToggle = showSidebarToggle
    self.isLoggedIn = isLoggedIn
  }

  var homeRoute: SiteRoute.View {
    if isLoggedIn {
      return .project(.index)
    }
    return .home
  }

  var body: some HTML<HTMLTag.nav> {
    nav(
      .class(
        """
        navbar w-full bg-base-300 text-base-content shadow-sm mb-4
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
        .tooltip(isLoggedIn ? "Projects" : "Home", position: .right)
      }

      div(.class("flex-none")) {
        div(.class("flex items-end space-x-4")) {

          DuctulatorButton()
            .attributes(.class("btn-ghost btn-primary text-lg"))
            .tooltip("Duct size calculator", position: .left)

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
                li {
                  a(.href(route: .user(.profile(.index)))) { "Profile" }
                }
                li {
                  a(.href(route: .user(.logout))) { "Logout" }
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
