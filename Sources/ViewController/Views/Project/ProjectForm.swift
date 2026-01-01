import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct ProjectForm: HTML, Sendable {

  let project: Project?

  init(
    project: Project? = nil
  ) {
    self.project = project
  }

  var body: some HTML {
    div(
      .id("projectForm"),
      .class(
        """
        fixed top-40 left-[25vw] w-1/2 z-50 text-gray-800
        bg-gray-200 border border-gray-400 
        rounded-lg shadow-lg mx-10
        """
      )
    ) {
      h1(.class("text-3xl font-bold pb-6 ps-2")) { "Project" }
      form(.class("space-y-4 p-4")) {
        div {
          label(.for("name")) { "Name" }
          Input(id: "name", placeholder: "Name")
            .attributes(.type(.text), .required, .autofocus)
        }
        div {
          label(.for("streetAddress")) { "Address" }
          Input(id: "streetAddress", placeholder: "Street Address")
            .attributes(.type(.text), .required)
        }
        div {
          label(.for("city")) { "City" }
          Input(id: "city", placeholder: "City")
            .attributes(.type(.text), .required)
        }
        div {
          label(.for("state")) { "State" }
          Input(id: "state", placeholder: "State")
            .attributes(.type(.text), .required)
        }
        div {
          label(.for("zipCode")) { "Zip" }
          Input(id: "zipCode", placeholder: "Zip code")
            .attributes(.type(.text), .required)
        }

        Row {
          div {}
          div(.class("space-x-4")) {
            CancelButton()
              .attributes(
                .hx.get(route: .project(.form(dismiss: true))),
                .hx.target("#projectForm"),
                .hx.swap(.outerHTML)
              )
            SubmitButton()
          }
        }
      }
    }
  }

}
