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
    div(.class("space-y-4")) {
      Row {
        h1(.class("text-2xl font-bold")) { "Component Pressure Losses" }
        LabeledContent("Total") {
          Badge(number: total)
        }
      }
      .attributes(.class("px-4"))

      div(.class("overflow-x-auto")) {
        table(.class("table table-zebra")) {
          thead {
            tr(.class("text-xl font-bold")) {
              th { "Name" }
              th { "Value" }
              th {
                div(.class("flex justify-end mx-auto")) {
                  Tooltip("Add Component Loss") {
                    PlusButton()
                      .attributes(
                        .class("btn-ghost text-2xl me-2"),
                        .showModal(id: ComponentLossForm.id())
                      )
                  }
                }
              }
            }
          }
          tbody {
            for row in componentPressureLosses {
              TableRow(row: row)
            }
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
            Tooltip("Delete", position: .bottom) {
              TrashButton()
                .attributes(
                  .class("join-item btn-ghost"),
                  .hx.delete(
                    route: .project(
                      .detail(row.projectID, .componentLoss(.delete(row.id)))
                    )
                  ),
                  .hx.target("body"),
                  .hx.swap(.outerHTML),
                  .hx.confirm("Are your sure?")

                )
            }
            Tooltip("Edit", position: .bottom) {
              EditButton()
                .attributes(
                  .class("join-item btn-ghost"),
                  .showModal(id: ComponentLossForm.id(row))
                )
            }
          }

          ComponentLossForm(dismiss: true, projectID: row.projectID, componentLoss: row)
        }
      }
    }
  }
}
