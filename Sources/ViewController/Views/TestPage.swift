import Dependencies
import Elementary
import Foundation
import ManualDClient
import ManualDCore
import Styleguide

struct TestPage: HTML, Sendable {
  // let ductSizes: DuctSizes

  var body: some HTML {
    div {
      Navbar(showSidebarToggle: false, isLoggedIn: false)
      div(.class("flex justify-center items-center px-10")) {
        div(
          .class(
            """
            bg-base-300 rounded-3xl shadow-3xl
            p-6 w-full
            """
          )
        ) {
          div(.class("flex space-x-6 items-center text-4xl")) {
            SVG(.calculator)
            h1(.class("text-4xl font-bold me-10")) {
              "Duct Size"
            }
          }

          p(.class("text-primary font-bold italic")) {
            "Calculate duct size for the given parameters"
          }

          form(
            .class("space-y-4 mt-6"),
            .action("#")
          ) {
            LabeledInput(
              "CFM",
              .required,
              .type(.number),
              .placeholder("1000"),
              .name("cfm")
            )

            LabeledInput(
              "Friction Rate",
              .value("0.06"),
              .required,
              .type(.number),
              .name("frictionRate")
            )

            LabeledInput(
              "Height",
              .required,
              .type(.number),
              .placeholder("Height (Optional)"),
              .name("frictionRate")
            )

            SubmitButton()
              .attributes(.class("btn-block mt-6"))
          }
        }

        // Populate when submitted
        div(.id(Result.id)) {}
      }
    }
  }

  struct Result: HTML, Sendable {
    static let id = "resultView"

    let ductSize: ManualDClient.DuctSize
    let rectangularSize: ManualDClient.RectangularSize?

    var body: some HTML<HTMLTag.div> {
      div(.id(Self.id)) {

      }
    }
  }
}
