import Elementary
import ElementaryHTMX
import Fluent
import ManualDCore
import Styleguide
import Vapor

struct ProjectsTable: HTML, Sendable {

  let userID: User.ID
  let projects: Page<Project>

  init(userID: User.ID, projects: Page<Project>) {
    self.userID = userID
    self.projects = projects
  }

  var body: some HTML {
    div {
      Row {
        h1(.class("text-2xl font-bold")) { "Projects" }
        div(
          .class("tooltip tooltip-left"),
          .data("tip", value: "Add project")
        ) {
          button(
            .class("btn btn-primary w-[40px] text-2xl"),
            .hx.get(route: .project(.form(dismiss: false))),
            .hx.target("#projectForm"),
            .hx.swap(.outerHTML)
          ) {
            "+"
          }
        }
      }
      .attributes(.class("pb-6"))

      div(.class("overflow-x-auto rounded-box border")) {
        table(.class("table table-zebra")) {
          thead {
            tr {
              th { Label("Date") }
              th { Label("Name") }
              th { Label("Address") }
              th {}
            }
          }
          tbody {
            Rows(projects: projects)
          }
        }
      }

      ProjectForm(dismiss: true)
    }
  }
}

extension ProjectsTable {
  struct Rows: HTML, Sendable {
    let projects: Page<Project>

    var body: some HTML {
      for project in projects.items {
        tr(.id("\(project.id)")) {
          td { DateView(project.createdAt) }
          td { "\(project.name)" }
          td { "\(project.streetAddress)" }
          td {
            a(
              .class("btn btn-success"),
              .href(route: .project(.detail(project.id)))
            ) { ">" }
          }
        }
      }
      // Have a row that when revealed fetches the next page,
      // if there are more pages left.
      if projects.metadata.pageCount > projects.metadata.page {
        tr(
          .hx.get(route: .project(.page(page: projects.metadata.page + 1, limit: 25))),
          .hx.trigger(.event(.revealed)),
          .hx.swap(.outerHTML),
          .hx.target("this"),
          .hx.indicator("next .htmx-indicator")
        ) {
          Indicator(size: .lg)
        }
      }
    }
  }
}
