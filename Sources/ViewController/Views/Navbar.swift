import Elementary
import ManualDCore
import Styleguide

struct Navbar: HTML, Sendable {
  let sidebarToggle: Bool

  var body: some HTML<HTMLTag.nav> {
    nav(
      .class(
        """
        navbar w-full bg-base-300 text-base-content shadow-sm mb-4
        """
      )
    ) {
      div(.class("flex flex-1 space-x-4 items-center")) {
        if sidebarToggle {
          Tooltip("Open sidebar", position: .right) {
            label(
              .for("my-drawer-1"),
              .class("size-7"),
              .init(name: "aria-label", value: "open sidebar")
            ) {
              SVG(.sidebarToggle)
            }
            .navButton()
          }

        }

        Tooltip("Home", position: .right) {
          a(
            .class("flex w-fit h-fit text-xl items-end px-4 py-2"),
            .href(route: .project(.index))
          ) {
            img(
              .src("/images/mand_logo_sm.webp"),
            )
            span { "Duct Calc" }
          }
          .navButton()
        }
      }
      div(.class("flex-none")) {
        a(
          .href(route: .user(.profile(.index))),
        ) {
          SVG(.circleUser)
        }
        .navButton()
        // details(.class("dropdown dropdown-left dropdown-bottom")) {
        //   summary(.class("btn w-fit px-4 py-2")) {
        //     SVG(.circleUser)
        //   }
        //   .navButton()
        //
        //   ul(
        //     .class(
        //       """
        //       menu dropdown-content bg-base-100
        //       rounded-box z-1 w-fit p-2 shadow-sm
        //       """
        //     )
        //   ) {
        //     li(.class("w-full")) {
        //       // TODO: Save theme to user profile ??
        //       div(.class("flex justify-between p-4 space-x-6")) {
        //         Label("Theme")
        //         input(.type(.checkbox), .class("toggle theme-controller"), .value("light"))
        //       }
        //     }
        //   }
        //
        //   // button(.class("w-fit px-4 py-2")) {
        //   //   SVG(.circleUser)
        //   // }
        //   // .navButton()
        // }
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
