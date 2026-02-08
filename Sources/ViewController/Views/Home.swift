import Elementary
import ElementaryHTMX

struct HomeView: HTML, Sendable {

  var body: some HTML {
    div(.class("flex justify-end me-4")) {
      button(
        .class("btn btn-ghost btn-secondary text-lg"),
        .hx.get(route: .login(.index())),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {
        "Login"
      }
    }
    div(.class("hero min-h-screen")) {
      div(
        .class(
          """
          hero-content text-center bg-base-200 dark:bg-base-300
          min-w-[80%] min-h-[400px] rounded-3xl shadow-3xl
          """
        )
      ) {
        div {
          header
          a(
            .class("btn btn-ghost text-md italic"),
            .href("https://git.housh.dev/michael/swift-manual-d"),
            .target(.blank)
          ) {
            "Open source residential duct design program"
          }
          p(.class("text-xl py-6")) {
            """
            Manual-D™ speed sheet, but on the web!
            """
          }
          button(
            .class("btn btn-xl bg-violet-600 mt-6"),
            .hx.get(route: .signup(.index)),
            .hx.target("body"),
            .hx.swap(.outerHTML)
          ) {
            "Get Started"
          }
          p(.class("text-xs italic mt-8")) {
            """
            Manual-D™ is a trademark of Air Conditioning Contractors of America (ACCA).

            This site is not designed by or affiliated with ACCA.
            """
          }
        }
      }
    }
  }

  var header: some HTML<HTMLTag.div> {
    div(.class("flex justify-center items-center")) {
      div(
        .class(
          """
          flex border-b-8 border-sky-600 
          text-8xl font-bold my-auto space-2
          """
        )
      ) {
        h1(.class("me-2")) { "Duct Calc" }
        div(.class("")) {
          span(
            .class(
              """
              bg-violet-600 rounded-md
              text-5xl rotate-180 p-2
              """
            ),
            .style("writing-mode: vertical-rl")
          ) {
            "Pro"
          }
        }
      }
    }
  }
}
