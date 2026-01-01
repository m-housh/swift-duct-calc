import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ComponentPressureLossTable: HTML, Sendable {

  let componentPressureLosses: [ComponentPressureLoss]

  var body: some HTML {
    div(.id("cplTable")) {
      h1(.class("text-2xl font-bold pb-4")) { "Component Pressure Losses" }
      table(
        .class(
          "w-full border-collapse border border-gray-200 table-fixed"
        )
      ) {
        thead { tableHeader }
        tbody(.id("cplTableBody")) {
          Rows(componentPressureLosses: componentPressureLosses)
        }
      }
    }
    div(.id("componentLossForm")) {}
  }

  private var tableHeader: some HTML<HTMLTag.tr> {
    tr {
      th(.class("border border-gray-200 text-xl font-bold")) { "Name" }
      th(.class("border border-gray-200 text-xl font-bold")) { "Pressure Loss" }
      th(.class("border border-gray-200 text-xl font-bold")) {
        Row {
          div {}
          button(
            .class("px-2"),
            .hx.get(route: .frictionRate(.form(.componentPressureLoss))),
            .hx.target("#componentLossForm"),
            .hx.swap(.outerHTML)
          ) {
            Icon(.circlePlus)
          }
        }
      }
    }
  }

  private struct Rows: HTML, Sendable {
    let componentPressureLosses: [ComponentPressureLoss]

    var body: some HTML {
      for cpl in componentPressureLosses {
        tr {
          td(.class("border border-gray-200 p-2")) { cpl.name }
          td(.class("border border-gray-200 p-2")) { "\(cpl.value)" }
          td(.class("border border-gray-200 p-2")) {
            // FIX: Add edit button
          }
        }
      }
    }
  }
}
