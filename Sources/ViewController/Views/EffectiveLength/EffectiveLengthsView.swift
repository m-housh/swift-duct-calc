import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthsView: HTML, Sendable {

  let effectiveLengths: [EffectiveLength]

  var body: some HTML {
    div(
      .class("m-4")
    ) {
      Row {
        h1(.class("text-2xl font-bold")) { "Effective Lengths" }
        PlusButton()
          .attributes(
            .hx.get(route: .effectiveLength(.form(dismiss: false))),
            .hx.target("#effectiveLengthForm"),
            .hx.swap(.outerHTML)
          )
        // button(
        //   .hx.get(route: .effectiveLength(.form(dismiss: false))),
        //   .hx.target("#effectiveLengthForm"),
        //   .hx.swap(.outerHTML)
        // ) {
        //   Icon(.circlePlus)
        // }
      }
      .attributes(.class("pb-6"))

      div(
        .id("effectiveLengths"),
        .class("space-y-6")
      ) {
        for row in effectiveLengths {
          EffectiveLengthView(effectiveLength: row)
        }
      }

      EffectiveLengthForm(dismiss: true)
    }
  }

  private struct EffectiveLengthView: HTML, Sendable {

    let effectiveLength: EffectiveLength

    var straightLengthsTotal: Int {
      effectiveLength.straightLengths
        .reduce(into: 0) { $0 += $1 }
    }

    var groupsTotal: Double {
      effectiveLength.groups.reduce(into: 0) {
        $0 += ($1.value * Double($1.quantity))
      }
    }

    var body: some HTML<HTMLTag.div> {
      div(
        .class(
          """
          border border-gray-200 rounded-lg shadow-lg p-4
          """
        )
      ) {
        Row {
          span(.class("text-xl font-bold")) { effectiveLength.name }
        }
        Row {
          Label("Straight Lengths")
        }
        for length in effectiveLength.straightLengths {
          Row {
            div {}
            Number(length)
          }
        }

        Row {
          Label("Groups")
          Label("Equivalent Length")
          Label("Quantity")
        }
        .attributes(.class("border-b border-gray-200"))

        for group in effectiveLength.groups {
          Row {
            span { "\(group.group)-\(group.letter)" }
            Number(group.value)
            Number(group.quantity)
          }
        }
        Row {
          Label("Total")
          Number(Double(straightLengthsTotal) + groupsTotal, digits: 0)
            .attributes(.class("text-xl font-bold"))
        }
        .attributes(.class("border-b border-t border-gray-200"))
      }
    }
  }
}
