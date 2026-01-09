import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Load component losses when view appears??

struct ComponentPressureLossesView: HTML, Sendable {

  let componentPressureLosses: [ComponentPressureLoss]
  let projectID: Project.ID

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
        div(.class("flex space-x-4 items-center")) {
          h1(.class("text-2xl font-bold")) { "Component Pressure Losses" }
          div(.class("flex text-primary space-x-2 items-baseline")) {
            Number(total)
              .attributes(.class("text-xl font-bold badge badge-outline badge-primary"))
            span(.class("text-sm italic")) { "Total" }
          }
        }
        PlusButton()
          .attributes(
            .showModal(id: ComponentLossForm.id())
          )
      }

      table(.class("table table-zebra")) {
        thead {
          tr(.class("text-xl font-bold")) {
            th { "Name" }
            th { "Value" }
            th {}
          }
        }
        tbody {
          for row in componentPressureLosses {
            TableRow(row: row)
          }
        }

      }
    }
    ComponentLossForm(dismiss: true, projectID: projectID, componentLoss: nil)
  }

  struct TableRow: HTML, Sendable {
    let row: ComponentPressureLoss

    var body: some HTML<HTMLTag.tr> {
      tr(.class("text-lg")) {
        td { row.name }
        td { Number(row.value) }
        td {
          div(.class("flex join items-end justify-end mx-auto")) {
            TrashButton()
              .attributes(
                .class("join-item"),
                .hx.delete(
                  route: .project(
                    .detail(row.projectID, .componentLoss(.delete(row.id)))
                  )
                ),
                .hx.target("body"),
                .hx.swap(.outerHTML),
                .hx.confirm("Are your sure?")

              )
            EditButton()
              .attributes(
                .class("join-item"),
                .showModal(id: ComponentLossForm.id(row))
              )
          }

          ComponentLossForm(dismiss: true, projectID: row.projectID, componentLoss: row)
        }
      }
    }
  }
}
