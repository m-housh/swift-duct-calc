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
        showDuctulatorButton: false,
        isLoggedIn: isLoggedIn
      )
      div(.class("ductulator-shell")) {
        div(.class("ductulator-panel")) {
          div(.class("flex flex-wrap gap-3 items-center")) {
            SVG(.calculator)
            h1(.class("text-3xl font-bold")) {
              "Ductulator"
            }
          }

          p(.class("font-bold italic")) {
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

            fieldset(
              .class("fieldset bg-base-200 border-base-300 rounded-box border-p-4 mt-2")
            ) {
              legend(.class("fieldset-legend")) { "Friction Rate" }

              LabeledInput(
                "Value",
                // .class("input input-md w-full"),
                .name("frictionRate"),
                .value("0.06"),
                .required,
                .type(.number),
                .min("0.01"),
                .step("0.01"),
                .id("frictionRateInput"),
                .on(.change, "syncInputs('frictionRateSlider', 'frictionRateInput');")
              )

              input(
                .class("range range-sm range-accent w-full mt-3"),
                .type(.range),
                .min("0.00"),
                .max("0.2"),
                .step("0.01"),
                .value("0.06"),
                .id("frictionRateSlider"),
                .init(name: "aria-label", value: "Friction rate"),
                .on(.change, "syncInputs('frictionRateInput', 'frictionRateSlider');")
              )

              div(.class("flex justify-between px-2.5 text-xs")) {
                span { "0.00" }
                span { "0.05" }
                span { "0.10" }
                span { "0.15" }
                span { "0.20" }
              }
            }

            LabeledInput(
              "Height (inches, optional)",
              .name("height"),
              .type(.number),
              .placeholder("8"),
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
        .data(
          "result-summary",
          value:
            "Final round size: \(Int(ductSize.finalSize)) inches. Flex size: \(Int(ductSize.flexSize)) inches."
        ),
        .class(
          """
          ductulator-result
          """
        )
      ) {
        div(.class("flex flex-wrap gap-3 justify-between mb-4")) {
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

        dl(.class("ductulator-values")) {
          div {
            dt { Label("Calculated Size") }
            dd { Number(ductSize.calculatedSize, digits: 2) }
          }
          div {
            dt { Label("Final Size") }
            dd { Number(ductSize.finalSize) }
          }
          div {
            dt { Label("Flex Size") }
            dd { Number(ductSize.flexSize) }
          }
          if let rectangularSize {
            div {
              dt { Label("Rectangular Size") }
              dd { "\(rectangularSize.width) x \(rectangularSize.height)" }
            }
          }
          div {
            dt { Label("Velocity") }
            dd { Number(ductSize.velocity) }
          }
        }

      }
    }
  }
}
