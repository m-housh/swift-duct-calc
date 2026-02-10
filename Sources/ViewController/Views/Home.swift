import Elementary
import ElementaryHTMX
import Styleguide

struct HomeView: HTML, Sendable {

  var body: some HTML {
    div(  // Uncomment to test different theme's.
    // .data("theme", value: "cyberpunk")
    // NOTE: Footer background color will follow system theme.
    ) {
      div(.class("flex justify-end space-x-4 m-4")) {
        DuctulatorButton()
          .attributes(.class("btn-ghost btn-accent text-lg"))
          .tooltip("Duct size calculator", position: .left)

        button(
          .class("btn btn-ghost btn-secondary text-lg"),
          .hx.get(route: .login(.index())),
          .hx.target("body"),
          .hx.swap(.outerHTML),
          .hx.pushURL(true)
        ) {
          "Login"
        }
      }

      div(.class("mx-10 lg:mx-20")) {
        div(
          .class(
            """
            relative text-center bg-base-300
            rounded-3xl shadow-3xl overflow-hidden
            """
          )
        ) {
          div(
            .class(
              """
              bg-secondary text-xl font-bold 
              absolute top-10 -left-15
              px-6 py-2 w-[250px] -rotate-45
              """
            )
          ) {
            "BETA"
          }
          div {
            header
            a(
              .class("btn btn-ghost text-md text-primary font-bold italic"),
              .href("https://github.com/m-housh/swift-duct-calc"),
              .target(.blank)
            ) {
              "Open source residential duct design program"
            }
            p(.class("text-3xl py-6")) {
              """
              Manual-D™ speed sheet, but on the web!
              """
            }
            button(
              .class("btn btn-xl btn-primary mt-6"),
              .hx.get(route: .signup(.index)),
              .hx.target("body"),
              .hx.swap(.outerHTML)
            ) {
              "Get Started"
            }
            p(.class("text-xs italic my-6")) {
              """
              Manual-D™ is a trademark of Air Conditioning Contractors of America (ACCA).

              This site is not designed by or affiliated with ACCA.
              """
            }
          }
        }

        div(.class("grid grid-cols-1 md:grid-cols-2 gap-4 my-6")) {
          div(.class("border-3 border-accent rounded-lg shadow-lg p-4")) {
            div(.class("flex items-center space-x-4")) {
              div(.class("text-5xl text-primary font-bold")) {
                "Features"
              }
            }
            div(.class("text-xl ms-10 mt-10")) {
              ul(.class("list-disc")) {
                li {
                  div(
                    .class("font-bold italic bg-secondary rounded-lg shadow-lg px-4 w-fit")
                  ) {
                    "Built by humans"
                  }
                }
                li { "Fully open source." }
                li { "Great replacement for speed sheet users." }
                li { "Great for classrooms." }
                li { "Store your projects in one place." }
                li { "Export final project to pdf." }
                li { "Import room loads via CSV file." }
                li { "Web based." }
                li { "Self host (run on your own infrastructure)." }
              }
            }
          }

          div(.class("border-3 border-accent rounded-lg shadow-lg p-4")) {
            div(.class("text-5xl text-primary font-bold")) {
              "Coming Soon"
            }
            div(.class("text-xl ms-10 mt-10")) {
              ul(.class("list-disc")) {
                li { "API integration." }
                li { "Command line interface." }
                li { "Fitting selection tool." }
                li { "Room load import from PDF." }
              }
            }
          }
        }
      }
    }
  }

  // TODO: When beta flag is gone, then remove the responsive margin of the header.
  var header: some HTML<HTMLTag.div> {
    div(.class("flex justify-center mt-30 md:mt-15 lg:mt-6")) {
      div(
        .class(
          """
          flex items-end border-b-6 border-accent
          text-8xl font-bold my-auto space-2
          """
        )
      ) {
        h1(.class("me-2")) { "Duct Calc" }
        div {
          span(
            .class(
              """
              bg-secondary rounded-md
              text-5xl rotate-180 p-2 -mx-2
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
