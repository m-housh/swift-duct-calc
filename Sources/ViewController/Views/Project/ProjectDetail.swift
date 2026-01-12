import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectDetail: HTML, Sendable {
  let project: Project

  var body: some HTML {
    div {
      Row {
        h1(.class("text-2xl font-bold")) { "Project" }
        EditButton()
          .attributes(
            .class("btn-ghost"),
            .on(.click, "projectForm.showModal()")
          )
      }

      div(.class("overflow-x-auto")) {
        table(.class("table table-zebra text-lg")) {
          tbody {
            tr {
              td { Label("Name") }
              td { project.name }
            }
            tr {
              td { Label("Street Address") }
              td { project.streetAddress }
            }
            tr {
              td { Label("City") }
              td { project.city }
            }
            tr {
              td { Label("State") }
              td { project.state }
            }
            tr {
              td { Label("Zip") }
              td { project.zipCode }
            }
          }
        }
      }

      ProjectForm(dismiss: true, project: project)
    }
  }

}
