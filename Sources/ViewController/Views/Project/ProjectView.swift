import DatabaseClient
import Dependencies
import Elementary
import ManualDClient
import ManualDCore
import Styleguide

struct ProjectNavigation: Sendable {
  var project: Project
  var recent: [Project]
}

enum ProjectViewValue {
  @TaskLocal static var projectID = Project.ID(0)
  @TaskLocal static var navigation: ProjectNavigation?
}

struct ProjectView<Inner: HTML & Sendable>: HTML, Sendable {
  @Environment(ProjectViewValue.$navigation) var navigation
  let projectID: Project.ID
  let activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab
  let inner: Inner
  let completedSteps: Project.CompletedSteps
  var project: Project?

  init(
    projectID: Project.ID, activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab,
    completedSteps: Project.CompletedSteps, project: Project? = nil,
    @HTMLBuilder content: () -> Inner
  ) {
    self.projectID = projectID
    self.activeTab = activeTab
    self.completedSteps = completedSteps
    self.project = project
    self.inner = content()
  }

  private var currentProject: Project? { project ?? navigation?.project }

  var body: some HTML {
    div(.class("project-workspace"), .data("project-id", value: "\(projectID)")) {
      Navbar(shortcutsDialogID: ProjectShortcutsDialog.id)
      div(.class("project-layout")) {
        aside(.class("project-navigation")) {
          button(
            .type(.button), .class("project-switch"), .showModal(id: "recentProjects"),
            .init(name: "aria-label", value: "Switch project")
          ) {
            SVG(.mapPin)
            span {
              strong { currentProject?.name ?? "Project" }
              small { currentProject?.streetAddress ?? "Switch project" }
            }
            SVG(.chevronDown)
          }
          nav(.init(name: "aria-label", value: "Project")) {
            ul(.id("project-sidebar")) {
              row(
                "Project", icon: .mapPin, shortcut: "1", tab: .project, route: .index, complete: nil
              )
              row(
                "Rooms", icon: .doorClosed, shortcut: "2", tab: .rooms, route: .rooms(.index),
                complete: completedSteps.rooms)
              row(
                "Equipment", icon: .fan, shortcut: "3", tab: .equipment, route: .equipment(.index),
                complete: completedSteps.equipmentInfo)
              row(
                "Total effective length", icon: .rulerDimensionLine, shortcut: "4",
                tab: .equivalentLength, route: .equivalentLength(.index),
                complete: completedSteps.equivalentLength)
              row(
                "Friction rate", icon: .squareFunction, shortcut: "5", tab: .frictionRate,
                route: .frictionRate(.index), complete: completedSteps.frictionRate)
              row(
                "Duct sizes", icon: .wind, shortcut: "6", tab: .ductSizing,
                route: .ductSizing(.index), complete: nil)
            }
          }
          a(.class("all-projects-link"), .href(route: .project(.index))) { "All projects" }
        }
        div(.class("project-content"), .id("project-content"), .tabindex(-1)) {
          inner.environment(ProjectViewValue.$projectID, projectID)
        }
      }
      ModalForm(id: "recentProjects", title: "Switch project", dismiss: true) {
        p(.class("muted")) { "Recently opened" }
        div(.class("recent-projects")) {
          for project in navigation?.recent ?? (currentProject.map { [$0] } ?? []) {
            a(.class("recent-project"), .href(route: .project(.detail(project.id, .index)))) {
              SVG(.mapPin)
              span {
                strong { project.name }
                small { "\(project.streetAddress) · \(project.city), \(project.state)" }
              }
              if project.id == projectID { span(.class("current-project")) { "Current ✓" } }
            }.attributes(.init(name: "aria-current", value: "page"), when: project.id == projectID)
          }
        }
        a(.class("btn btn-outline mt-4"), .href(route: .project(.index))) { "View all projects" }
      }
      ProjectShortcutsDialog()
    }
  }

  private func row(
    _ title: String, icon: SVG.Key, shortcut: String,
    tab: SiteRoute.View.ProjectRoute.DetailRoute.Tab,
    route: SiteRoute.View.ProjectRoute.DetailRoute, complete: Bool?
  ) -> some HTML {
    li {
      a(
        .href(route: .project(.detail(projectID, route))),
        .title("\(title), Ctrl+Alt+\(shortcut)"),
        .init(name: "aria-keyshortcuts", value: "Control+Alt+\(shortcut)")
      ) {
        SVG(icon)
        span(.class("nav-label")) { title }
        if let complete {
          span(
            .class("project-step-status"),
            .init(name: "aria-label", value: complete ? "Complete" : "Incomplete")
          ) {
            if complete { "✓" }
          }
        }
      }.attributes(.init(name: "aria-current", value: "page"), when: activeTab == tab)
    }
  }
}

extension ManualDClient {

  func frictionRate(
    equipmentInfo: EquipmentInfo?,
    componentLosses: [ComponentPressureLoss],
    effectiveLength: EquivalentLength.MaxContainer
  ) async throws -> FrictionRate? {
    guard let staticPressure = equipmentInfo?.staticPressure else {
      return nil
    }
    guard let totalEquivalentLength = effectiveLength.totalEquivalentLength else {
      return nil
    }
    return try await self.frictionRate(
      .init(
        externalStaticPressure: staticPressure,
        componentPressureLosses: componentLosses,
        totalEquivalentLength: Int(totalEquivalentLength)
      )
    )
  }

}
