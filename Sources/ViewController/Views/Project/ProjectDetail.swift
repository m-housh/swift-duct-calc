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

      table(.class("table table-zebra text-lg")) {
        tbody {
          tr {
            td(.class("label font-bold")) { "Name" }
            td {
              div(.class("flex justify-end")) {
                project.name
              }
            }
          }
          tr {
            td(.class("label font-bold")) { "Street Address" }
            td {
              div(.class("flex justify-end")) {
                project.streetAddress
              }
            }
          }
          tr {
            td(.class("label font-bold")) { "City" }
            td {
              div(.class("flex justify-end")) {
                project.city
              }
            }
          }
          tr {
            td(.class("label font-bold")) { "State" }
            td {
              div(.class("flex justify-end")) {
                project.state
              }
            }
          }
          tr {
            td(.class("label font-bold")) { "Zip" }
            td {
              div(.class("flex justify-end")) {
                project.zipCode
              }
            }
          }
        }
      }

      ProjectForm(dismiss: true, project: project)
    }
  }

}
