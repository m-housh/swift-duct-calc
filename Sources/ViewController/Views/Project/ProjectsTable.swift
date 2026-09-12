import Elementary
import ElementaryHTMX
import Fluent
import ManualDCore
import Styleguide
import Vapor

struct ProjectsTable: HTML, Sendable {
  let userID: User.ID
  let projects: Page<Project>
  var query = ""

  var body: some HTML {
    div(.class("project-workspace project-directory")) {
      Navbar()
      div(.class("directory-content")) {
        PageTitleRow {
          div {
            PageTitle { "Projects" }
            p(.class("muted")) { "Your residential duct designs." }
          }
          button(.type(.button), .class("btn btn-primary"), .showModal(id: ProjectForm.id)) {
            SVG(.circlePlus)
            "Add Project"
          }
        }
        div(.class("project-panel")) {
          form(.method(.get), .action("/projects/search"), .class("project-toolbar")) {
            h2 { "All projects · \(projects.metadata.total)" }
            label(.class("project-search")) {
              span(.class("sr-only")) { "Find a project" }
              input(
                .type(.search), .id("project-search"), .name("q"), .value(query),
                .placeholder("Find a project…"), .class("input"),
                .init(name: "aria-keyshortcuts", value: "Control+K"))
              kbd { "Ctrl+K" }
            }
            button(.type(.submit), .class("btn btn-outline")) { "Search" }
          }
          div(
            .class("table-scroll"), .tabindex(0), .role("region"),
            .init(name: "aria-label", value: "Projects")
          ) {
            table(.class("table project-table")) {
              thead {
                tr {
                  th { "Project" }
                  th { "Address" }
                  th { "City" }
                  th { "Created" }
                  th { span(.class("sr-only")) { "Actions" } }
                }
              }
              tbody { Rows(projects: projects, paginate: query.isEmpty) }
            }
          }
          if projects.items.isEmpty {
            p(.class("empty-state")) {
              query.isEmpty
                ? "No projects yet. Add a project to start designing."
                : "No projects match your search."
            }
          }
          if !query.isEmpty {
            div(.class("project-toolbar")) {
              if projects.metadata.page > 1 {
                a(
                  .class("btn"),
                  .href(
                    route: .project(.search(.init(query: query, page: projects.metadata.page - 1))))
                ) { "Previous" }
              }
              if projects.metadata.page < projects.metadata.pageCount {
                a(
                  .class("btn"),
                  .href(
                    route: .project(.search(.init(query: query, page: projects.metadata.page + 1))))
                ) { "Next" }
              }
            }
          }
        }
      }
      ProjectForm(dismiss: true)
    }
  }

  struct Rows: HTML, Sendable {
    let projects: Page<Project>
    var paginate = true
    var body: some HTML {
      for project in projects.items {
        tr(.id("\(project.id)"), .data("project-row", value: "")) {
          td {
            a(.class("project-name"), .href(route: .project(.detail(project.id, .index)))) {
              project.name
            }
          }
          td { project.streetAddress }
          td { "\(project.city), \(project.state)" }
          td { DateView(project.createdAt) }
          td {
            TrashButton("Delete \(project.name)").attributes(
              .class("btn-ghost"), .hx.delete(route: .project(.delete(id: project.id))),
              .hx.confirm("Delete this project and all of its design data?"), .hx.target("body"),
              .hx.swap(.outerHTML))
          }
        }
      }
      if paginate && projects.metadata.pageCount > projects.metadata.page {
        tr(
          .hx.get(route: .project(.page(.next(projects)))), .hx.trigger(.event(.revealed)),
          .hx.swap(.outerHTML), .hx.target("this")
        ) {
          td(.init(name: "colspan", value: "5")) { Indicator(size: .lg) }
        }
      }
    }
  }
}
