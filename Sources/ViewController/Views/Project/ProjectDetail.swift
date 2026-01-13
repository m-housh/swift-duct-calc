import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectDetail: HTML, Sendable {
  let project: Project

  var body: some HTML {
    div {
      Row {
        h1(.class("text-3xl font-bold")) { "Project" }
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
              td { "Name" }
              td {
                div(.class("flex justify-end")) {
                  project.name
                }
              }
            }
            tr {
              td { "Street Address" }
              td {
                div(.class("flex justify-end")) {
                  project.streetAddress
                }
              }
            }
            tr {
              td { "City" }
              td {
                div(.class("flex justify-end")) {
                  project.city
                }
              }
            }
            tr {
              td { "State" }
              td {
                div(.class("flex justify-end")) {
                  project.state
                }
              }
            }
            tr {
              td { "Zip" }
              td {
                div(.class("flex justify-end")) {
                  project.zipCode
                }
              }
            }
          }
        }
      }

      ProjectForm(dismiss: true, project: project)
    }
  }

}
