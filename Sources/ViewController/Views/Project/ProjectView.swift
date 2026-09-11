import DatabaseClient
import Dependencies
import Elementary
import ManualDClient
import ManualDCore
import Styleguide

enum ProjectViewValue {
  @TaskLocal static var projectID = Project.ID(0)
}

struct ProjectView<Inner: HTML & Sendable>: HTML, Sendable {
  let projectID: Project.ID
  let activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab
  let inner: Inner
  let completedSteps: Project.CompletedSteps

  init(
    projectID: Project.ID,
    activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab,
    completedSteps: Project.CompletedSteps,
    @HTMLBuilder content: () -> Inner
  ) {
    self.projectID = projectID
    self.activeTab = activeTab
    self.inner = content()
    self.completedSteps = completedSteps
  }

  var body: some HTML {
    Navbar(shortcutsDialogID: ProjectShortcutsDialog.id)
    div(.class("project-layout")) {
      details(.class("project-navigation"), .init(name: "open", value: "")) {
        summary { "Project navigation" }
        nav(.init(name: "aria-label", value: "Project")) {
          ul(.id("project-sidebar")) {
            row("Project", shortcut: "1", tab: .project, route: .index, complete: nil)
            row(
              "Rooms", shortcut: "2", tab: .rooms, route: .rooms(.index),
              complete: completedSteps.rooms)
            row(
              "Equipment", shortcut: "3", tab: .equipment, route: .equipment(.index),
              complete: completedSteps.equipmentInfo)
            row(
              "T.E.L.", shortcut: "4", tab: .equivalentLength, route: .equivalentLength(.index),
              complete: completedSteps.equivalentLength)
            row(
              "Friction Rate", shortcut: "5", tab: .frictionRate, route: .frictionRate(.index),
              complete: completedSteps.frictionRate)
            row(
              "Duct Sizes", shortcut: "6", tab: .ductSizing, route: .ductSizing(.index),
              complete: nil)
          }
        }
      }
      div(.class("project-content"), .id("project-content"), .tabindex(-1)) {
        inner.environment(ProjectViewValue.$projectID, projectID)
      }
    }
    ProjectShortcutsDialog()
  }

  private func row(
    _ title: String,
    shortcut: String,
    tab: SiteRoute.View.ProjectRoute.DetailRoute.Tab,
    route: SiteRoute.View.ProjectRoute.DetailRoute,
    complete: Bool?
  ) -> some HTML {
    li {
      a(
        .href(route: .project(.detail(projectID, route))),
        .title("\(title), Ctrl+Alt+\(shortcut)"),
        .init(name: "aria-keyshortcuts", value: "Control+Alt+\(shortcut)")
      ) {
        span { title }
        span(.class("text-xs"), .init(name: "aria-hidden", value: "true")) {
          "Ctrl+Alt+\(shortcut)"
        }
        if let complete {
          span(.class("project-step-status")) { complete ? "Complete" : "Incomplete" }
        }
      }
      .attributes(.init(name: "aria-current", value: "page"), when: activeTab == tab)
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
