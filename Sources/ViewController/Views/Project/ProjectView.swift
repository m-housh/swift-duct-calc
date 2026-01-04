import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Need a back button to navigate to all projects table.

struct ProjectView<Inner: HTML>: HTML, Sendable where Inner: Sendable {
  let projectID: Project.ID
  let activeTab: Sidebar.ActiveTab
  let inner: Inner

  init(
    projectID: Project.ID,
    activeTab: Sidebar.ActiveTab,
    @HTMLBuilder inner: () -> Inner
  ) {
    self.projectID = projectID
    self.activeTab = activeTab
    self.inner = inner()
  }

  var body: some HTML {
    div {
      div(.class("flex flex-row")) {
        Sidebar(active: activeTab, projectID: projectID)
        main(.class("flex flex-col h-screen w-full px-6 py-10")) {
          inner
        }
      }
    }
  }
}

// TODO: Update to use DaisyUI drawer.
struct Sidebar: HTML {

  let active: ActiveTab
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

      // TODO: Move somewhere outside of the sidebar.
      Row {
        Label("Theme")
        input(.type(.checkbox), .class("toggle theme-controller"), .value("light"))
      }
      .attributes(.class("p-4"))

      row(title: "Project", icon: .mapPin, route: .project(.detail(projectID, .index)))
        .attributes(.data("active", value: active == .projects ? "true" : "false"))

      row(title: "Rooms", icon: .doorClosed, route: .project(.detail(projectID, .rooms(.index))))
        .attributes(.data("active", value: active == .rooms ? "true" : "false"))

      row(title: "Equivalent Lengths", icon: .rulerDimensionLine, route: .effectiveLength(.index))
        .attributes(.data("active", value: active == .effectiveLength ? "true" : "false"))

      row(title: "Friction Rate", icon: .squareFunction, route: .frictionRate(.index))
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

extension Sidebar {
  enum ActiveTab: Equatable, Sendable {
    case projects
    case rooms
    case effectiveLength
    case frictionRate
    case ductSizing
  }
}
