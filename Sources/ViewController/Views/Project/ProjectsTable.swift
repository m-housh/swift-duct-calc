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
      Navbar(sidebarToggle: false)
      div(.class("m-6")) {
        Row {
          PageTitle { "Projects" }
          Tooltip("Add project") {
            PlusButton()
              .attributes(
                .class("btn-ghost"),
                .showModal(id: ProjectForm.id)
              )
          }
        }
        .attributes(.class("pb-6"))

        div(.class("overflow-x-auto")) {
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
}

extension ProjectsTable {
  struct Rows: HTML, Sendable {
    let projects: Page<Project>

    func tooltipPosition(_ n: Int) -> TooltipPosition {
      if projects.metadata.page == 1 && projects.items.count == 1 {
        return .left
      } else if n == (projects.items.count - 1) {
        return .left
      } else {
        return .bottom
      }
    }

    var body: some HTML {
      for (n, project) in projects.items.enumerated() {
        tr(.id("\(project.id)")) {
          td { DateView(project.createdAt) }
          td { "\(project.name)" }
          td { "\(project.streetAddress)" }
          td {
            div(.class("flex justify-end space-x-6")) {
              div(.class("join")) {
                Tooltip("Delete project", position: tooltipPosition(n)) {
                  TrashButton()
                    .attributes(
                      .class("join-item btn-ghost"),
                      .hx.delete(route: .project(.delete(id: project.id))),
                      .hx.confirm("Are you sure?"),
                      .hx.target("closest tr")
                    )
                }
                Tooltip("View project", position: tooltipPosition(n)) {
                  a(
                    .class("join-item btn btn-success btn-ghost"),
                    .href(route: .project(.detail(project.id, .rooms(.index))))
                  ) {
                    SVG(.chevronRight)
                  }
                }
              }
            }
          }
        }
      }
      // Have a row that when revealed fetches the next page,
      // if there are more pages left.
      if projects.metadata.pageCount > projects.metadata.page {
        tr(
          .hx.get(route: .project(.page(.next(projects)))),
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
