import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectDetail: HTML, Sendable {
  let project: Project

  var body: some HTML {
    div(
      .class(
        """
        border border-gray-200 rounded-lg shadow-lg space-y-4 p-4 m-4
        """
      )
    ) {
      Row {
        h1(.class("text-2xl font-bold")) { "Project" }
        EditButton()
          .attributes(
            .hx.get(route: .project(.form(dismiss: false))),
            .hx.target("#projectForm"),
            .hx.swap(.outerHTML)
          )
      }

      Row {
        Label("Name")
        span { project.name }
      }
      .attributes(.class("border-b border-gray-200"))

      Row {
        Label("Address")
        span { project.streetAddress }
      }
      .attributes(.class("border-b border-gray-200"))

      Row {
        Label("City")
        span { project.city }
      }
      .attributes(.class("border-b border-gray-200"))

      Row {
        Label("State")
        span { project.state }
      }
      .attributes(.class("border-b border-gray-200"))

      Row {
        Label("Zip")
        span { project.zipCode }
      }
    }

    div(.id("projectForm")) {}
  }
}
