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
    Navbar()
    div(.class("project-layout")) {
      details(.class("project-navigation"), .init(name: "open", value: "")) {
        summary { "Project navigation" }
        nav(.init(name: "aria-label", value: "Project")) {
          ul {
            row("Project", tab: .project, route: .index, complete: nil)
            row("Rooms", tab: .rooms, route: .rooms(.index), complete: completedSteps.rooms)
            row("Equipment", tab: .equipment, route: .equipment(.index), complete: completedSteps.equipmentInfo)
            row("T.E.L.", tab: .equivalentLength, route: .equivalentLength(.index), complete: completedSteps.equivalentLength)
            row("Friction Rate", tab: .frictionRate, route: .frictionRate(.index), complete: completedSteps.frictionRate)
            row("Duct Sizes", tab: .ductSizing, route: .ductSizing(.index), complete: nil)
          }
        }
      }
      div(.class("project-content"), .id("project-content"), .tabindex(-1)) {
        inner.environment(ProjectViewValue.$projectID, projectID)
      }
    }
  }

  private func row(
    _ title: String,
    tab: SiteRoute.View.ProjectRoute.DetailRoute.Tab,
    route: SiteRoute.View.ProjectRoute.DetailRoute,
    complete: Bool?
  ) -> some HTML {
    li {
      a(.href(route: .project(.detail(projectID, route)))) {
        span { title }
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
