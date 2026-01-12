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

  // var body: some HTML {
  //   div(
  //     .class(
  //       """
  //       space-y-4 p-4 m-4
  //       """
  //     )
  //   ) {
  //     Row {
  //       h1(.class("text-2xl font-bold")) { "Project" }
  //       EditButton()
  //         .attributes(
  //           .class("btn-ghost"),
  //           .on(.click, "projectForm.showModal()")
  //         )
  //     }
  //
  //     Row {
  //       Label("Name")
  //       span { project.name }
  //     }
  //     .attributes(.class("border-b border-gray-200"))
  //
  //     Row {
  //       Label("Address")
  //       span { project.streetAddress }
  //     }
  //     .attributes(.class("border-b border-gray-200"))
  //
  //     Row {
  //       Label("City")
  //       span { project.city }
  //     }
  //     .attributes(.class("border-b border-gray-200"))
  //
  //     Row {
  //       Label("State")
  //       span { project.state }
  //     }
  //     .attributes(.class("border-b border-gray-200"))
  //
  //     Row {
  //       Label("Zip")
  //       span { project.zipCode }
  //     }
  //   }
  //
  //   ProjectForm(dismiss: true, project: project)
  // }
}

