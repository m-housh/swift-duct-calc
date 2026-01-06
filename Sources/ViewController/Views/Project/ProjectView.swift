import DatabaseClient
import Dependencies
import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Make view async and load based on the active tab.

struct ProjectView: HTML, Sendable {
  @Dependency(\.database) var database

  let projectID: Project.ID
  let activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab

  init(
    projectID: Project.ID,
    activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab
  ) {
    self.projectID = projectID
    self.activeTab = activeTab
  }

  var body: some HTML {
    div {
      div(.class("flex flex-row")) {
        Sidebar(active: activeTab, projectID: projectID)
        main(.class("flex flex-col h-screen w-full px-6 py-10")) {
          switch self.activeTab {
          case .project:
            if let project = try await database.projects.get(projectID) {
              ProjectDetail(project: project)
            } else {
              div {
                "FIX ME!"
              }
            }
          case .rooms:
            try await RoomsView(
              projectID: projectID,
              rooms: database.rooms.fetch(projectID),
              sensibleHeatRatio: database.projects.getSensibleHeatRatio(projectID)
            )

          case .effectiveLength:
            try await EffectiveLengthsView(
              effectiveLengths: database.effectiveLength.fetch(projectID)
            )
          case .frictionRate:
            try await FrictionRateView(
              equipmentInfo: database.equipment.fetch(projectID),
              componentLosses: database.componentLoss.fetch(projectID), projectID: projectID)
          case .ductSizing:
            div { "FIX ME!" }

          }
        }
      }
    }
  }
}

// TODO: Update to use DaisyUI drawer.
struct Sidebar: HTML {

  let active: SiteRoute.View.ProjectRoute.DetailRoute.Tab
  let projectID: Project.ID

  var body: some HTML {
    aside(
      .class(
        """
        h-screen sticky top-0 max-w-[280px] flex-none 
        border-r-2 border-gray-200 
        shadow-lg
        """
      )
    ) {

      div(.class("flex")) {
        // TODO: Move somewhere outside of the sidebar.
        button(
          .class("w-full btn btn-secondary"),
          .hx.get(route: .project(.index)),
          .hx.target("body"),
          .hx.pushURL(true),
          .hx.swap(.outerHTML),
        ) {
          "< All Projects"
        }
      }

      Row {
        Label("Theme")
        input(.type(.checkbox), .class("toggle theme-controller"), .value("light"))
      }
      .attributes(.class("p-4"))

      row(
        title: "Project",
        icon: .mapPin,
        route: .project(.detail(projectID, .index(tab: .project)))
      )
      .attributes(.data("active", value: active == .project ? "true" : "false"))

      row(title: "Rooms", icon: .doorClosed, route: .project(.detail(projectID, .rooms(.index))))
        .attributes(.data("active", value: active == .rooms ? "true" : "false"))

      row(title: "Equivalent Lengths", icon: .rulerDimensionLine, route: .effectiveLength(.index))
        .attributes(.data("active", value: active == .effectiveLength ? "true" : "false"))

      row(
        title: "Friction Rate",
        icon: .squareFunction,
        route: .project(.detail(projectID, .frictionRate(.index)))
      )
      .attributes(.data("active", value: active == .frictionRate ? "true" : "false"))

      row(title: "Duct Sizes", icon: .wind, href: "#")
        .attributes(.data("active", value: active == .ductSizing ? "true" : "false"))
    }
  }

  // TODO: Use SiteRoute.View routes as href.
  private func row(
    title: String,
    icon: Icon.Key,
    href: String
  ) -> some HTML<HTMLTag.a> {
    a(
      .class(
        """
        flex w-full items-center gap-4
        hover:bg-gray-300 hover:text-gray-800
        data-[active=true]:bg-gray-300 data-[active=true]:text-gray-800
        px-4 py-2
        """
      ),
      .href(href)
    ) {
      Icon(icon)
      span(.class("text-xl")) {
        title
      }
    }
  }

  private func row(
    title: String,
    icon: Icon.Key,
    route: SiteRoute.View
  ) -> some HTML<HTMLTag.a> {
    row(title: title, icon: icon, href: SiteRoute.View.router.path(for: route))
  }
}
