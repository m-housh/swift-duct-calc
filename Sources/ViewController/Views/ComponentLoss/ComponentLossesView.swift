import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ComponentPressureLossesView: HTML, Sendable {

  let componentPressureLosses: [ComponentPressureLoss]
  let projectID: Project.ID

  private var total: Double {
    componentPressureLosses.total
  }

  private var sortedLosses: [ComponentPressureLoss] {
    componentPressureLosses.sorted {
      $0.value > $1.value
    }
  }

  var body: some HTML {
    div(.class("space-y-4")) {
      Row {
        h1(.class("text-2xl font-bold")) { "Component Pressure Losses" }
        PlusButton()
          .attributes(
            .class("btn-primary text-2xl me-2"),
            .showModal(id: ComponentLossForm.id())
          )
          .tooltip("Add component loss")
      }
      .attributes(.class("px-4"))

      table(.class("table table-zebra")) {
        thead {
          tr(.class("text-xl font-bold")) {
            th { "Name" }
            th { "Value" }
            th(.class("min-w-[200px]")) {}
          }
        }
        tbody {
          for row in sortedLosses {
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
