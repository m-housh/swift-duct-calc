import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectDetail: HTML, Sendable {
  let project: Project

  var body: some HTML {
    div {
      PageTitleRow {
        PageTitle { "Project" }

        EditButton(accessibilityLabel: "Edit project")
          .attributes(
            .class("btn-primary"),
            .showModal(id: ProjectForm.id)
          )
          .tooltip("Edit project", position: .left)
      }

      table(.class("table details-table table-zebra text-lg")) {
        tbody {
          tr {
            th(.class("font-bold"), .init(name: "scope", value: "row")) { "Name" }
            td {
              div(.class("flex justify-end")) {
                project.name
              }
            }
          }
          tr {
            th(.class("font-bold"), .init(name: "scope", value: "row")) { "Street Address" }
            td {
              div(.class("flex justify-end")) {
                project.streetAddress
              }
            }
          }
          tr {
            th(.class("font-bold"), .init(name: "scope", value: "row")) { "City" }
            td {
              div(.class("flex justify-end")) {
                project.city
              }
            }
          }
          tr {
            th(.class("font-bold"), .init(name: "scope", value: "row")) { "State" }
            td {
              div(.class("flex justify-end")) {
                project.state
              }
            }
          }
          tr {
            th(.class("font-bold"), .init(name: "scope", value: "row")) { "Zip" }
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
