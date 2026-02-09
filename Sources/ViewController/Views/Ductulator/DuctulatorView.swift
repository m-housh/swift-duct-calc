import Dependencies
import Elementary
import ElementaryHTMX
import Foundation
import ManualDClient
import ManualDCore
import Styleguide

struct DuctulatorView: HTML, Sendable {

  let isLoggedIn: Bool

  init(isLoggedIn: Bool = false) {
    self.isLoggedIn = isLoggedIn
  }

  var body: some HTML {
    div {
      Navbar(
        showSidebarToggle: false,
        isLoggedIn: isLoggedIn
      )
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
              "Ductulator"
            }
          }

          p(.class("text-primary font-bold italic")) {
            "Calculate duct size for the given parameters"
          }

          form(
            .class("space-y-4 mt-6"),
            .hx.post(route: .ductulator(.index)),
            .hx.target("#\(Result.id)"),
            .hx.swap(.outerHTML)
          ) {
            LabeledInput(
              "CFM",
              .name("cfm"),
              .type(.number),
              .placeholder("1000"),
              .required,
              .autofocus
            )

            LabeledInput(
              "Friction Rate",
              .name("frictionRate"),
              .value("0.06"),
              .required,
              .type(.number),
              .min("0.01"),
              .step("0.01")
            )

            LabeledInput(
              "Height",
              .name("height"),
              .type(.number),
              .placeholder("Height (Optional)"),
            )

            SubmitButton()
              .attributes(.class("btn-block mt-6"))
          }

          // Populate when submitted
          div(.id(Result.id)) {}
        }
      }
    }
  }

  struct Result: HTML, Sendable {
    static let id = "resultView"

    let ductSize: ManualDClient.DuctSize
    let rectangularSize: ManualDClient.RectangularSize?

    var body: some HTML<HTMLTag.div> {
      div(
        .id(Self.id),
        .class(
          """
          border-2 border-accent rounded-lg shadow-lg
          w-full p-6 my-6
          """
        )
      ) {
        div(.class("flex justify-between p-4")) {
          h2(.class("text-3xl font-bold")) { "Result" }
          button(
            .class("btn btn-primary"),
            .hx.get(route: .ductulator(.index)),
            .hx.target("body"),
            .hx.swap(.outerHTML)
          ) {
            "Reset"
          }
          .tooltip("Reset form", position: .left)
        }

        table(.class("table table-zebra text-lg font-bold")) {
          tbody {
            tr {
              td { Label("Calculated Size") }
              td { Number(ductSize.calculatedSize, digits: 2) }
            }
            tr {
              td { Label("Final Size") }
              td { Number(ductSize.finalSize) }
            }
            tr {
              td { Label("Flex Size") }
              td { Number(ductSize.flexSize) }
            }
            if let rectangularSize {
              tr {
                td { Label("Rectangular Size") }
                td { "\(rectangularSize.width) x \(rectangularSize.height)" }
              }
            }
          }
        }

      }
    }
  }
}
