import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ComponentPressureLossesView: HTML, Sendable {

  let componentPressureLosses: [ComponentPressureLoss]

  private var total: Double {
    componentPressureLosses.reduce(into: 0) { $0 += $1.value }
  }

  var body: some HTML {
    div(
      .class(
        """
        border border-gray-200 rounded-lg shadow-lg space-y-4 p-4
        """
      )
    ) {
      Row {
        h1(.class("text-2xl font-bold")) { "Component Pressure Losses" }
        button(
          .hx.get(route: .frictionRate(.form(.componentPressureLoss, dismiss: false))),
          .hx.target("#componentLossForm"),
          .hx.swap(.outerHTML)
        ) {
          Icon(.circlePlus)
        }
      }

      for row in componentPressureLosses {
        Row {
          Label { row.name }
          Number(row.value)
        }
        .attributes(.class("border-b border-gray-200"))
      }

      Row {
        Label { "Total" }
        Number(total)
          .attributes(.class("text-xl font-bold"))
      }
    }
    div(.id("componentLossForm")) {}
  }

}
