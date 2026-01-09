import DatabaseClient
import Dependencies
import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

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
    div(.class("h-screen w-full")) {

      div(.class("drawer lg:drawer-open")) {
        input(.id("my-drawer-1"), .type(.checkbox), .class("drawer-toggle"))

        div(.class("drawer-content p-4")) {
          label(
            .for("my-drawer-1"),
            .class("btn btn-square btn-ghost drawer-button size-7")
          ) {
            SVG(.sidebarToggle)
          }
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

          case .equivalentLength:
            try await EffectiveLengthsView(
              projectID: projectID,
              effectiveLengths: database.effectiveLength.fetch(projectID)
            )
          case .frictionRate:
            try await FrictionRateView(
              equipmentInfo: database.equipment.fetch(projectID),
              componentLosses: database.componentLoss.fetch(projectID),
              equivalentLengths: database.effectiveLength.fetchMax(projectID),
              projectID: projectID
            )
          case .ductSizing:
            div { "FIX ME!" }

          }
        }

        try await Sidebar(
          active: activeTab,
          projectID: projectID,
          completedSteps: database.projects.getCompletedSteps(projectID)
        )
      }
    }
  }
}

extension ProjectView {

  struct Sidebar: HTML {

    let active: SiteRoute.View.ProjectRoute.DetailRoute.Tab
    let projectID: Project.ID
    let completedSteps: Project.CompletedSteps

    var body: some HTML {

      div(.class("drawer-side is-drawer-close:overflow-visible")) {
        label(
          .for("my-drawer-1"), .init(name: "aria-label", value: "close sidebar"),
          .class("drawer-overlay")
        ) {}

        div(
          .class(
            """
            flex min-h-full flex-col items-start bg-base-200 
            is-drawer-close:min-w-[80px] is-drawer-open:min-w-[340px]
            """
          )
        ) {

          ul(.class("w-full")) {

            li(.class("w-full")) {
              div(
                .class("w-full is-drawer-close:tooltip is-drawer-close:tooltip-right"),
                .data("tip", value: "All Projects")
              ) {
                a(
                  .class(
                    """
                    flex btn btn-secondary btn-square btn-block 
                    is-drawer-close:items-center
                    """
                  ),
                  .hx.get(route: .project(.index)),
                  .hx.target("body"),
                  .hx.pushURL(true),
                  .hx.swap(.outerHTML),
                ) {
                  div(.class("flex is-drawer-open:space-x-4")) {
                    span { "<" }
                    span(.class("is-drawer-close:hidden")) { "All Projects" }
                  }
                }
              }
            }

            // FIX: Move to user profile / settings page.
            li(.class("w-full is-drawer-close:hidden")) {
              div(.class("flex justify-between p-4")) {
                Label("Theme")
                input(.type(.checkbox), .class("toggle theme-controller"), .value("light"))
              }
            }

            li(.class("w-full")) {
              row(
                title: "Project",
                icon: .mapPin,
                route: .project(.detail(projectID, .index(tab: .project))),
                isComplete: true
              )
              .attributes(.class("btn-active"), when: active == .project)
            }

            li(.class("w-full")) {
              row(
                title: "Rooms",
                icon: .doorClosed,
                route: .project(.detail(projectID, .rooms(.index))),
                isComplete: completedSteps.rooms
              )
              .attributes(.class("btn-active"), when: active == .rooms)
            }

            li(.class("w-full")) {
              row(
                title: "Equivalent Lengths",
                icon: .rulerDimensionLine,
                route: .project(.detail(projectID, .equivalentLength(.index))),
                isComplete: completedSteps.equivalentLength
              )
              .attributes(.class("btn-active"), when: active == .equivalentLength)

            }
            li(.class("w-full")) {
              row(
                title: "Friction Rate",
                icon: .squareFunction,
                route: .project(.detail(projectID, .frictionRate(.index))),
                isComplete: completedSteps.frictionRate
              )
              .attributes(.class("btn-active"), when: active == .frictionRate)

            }
            li(.class("w-full")) {
              row(
                title: "Duct Sizes", icon: .wind, href: "#", isComplete: false, hideIsComplete: true
              )
              .attributes(.class("btn-active"), when: active == .ductSizing)
            }
          }
        }
      }
    }

    // TODO: Use SiteRoute.View routes as href.
    private func row(
      title: String,
      icon: SVG.Key,
      href: String,
      isComplete: Bool,
      hideIsComplete: Bool = false
    ) -> some HTML<HTMLTag.a> {
      a(
        .class(
          """
          flex w-full btn btn-soft btn-square btn-block 
          is-drawer-open:justify-between is-drawer-close:items-center
          is-drawer-close:tooltip is-drawer-close:tooltip-right
          """
        ),
        .href(href),
        .data("tip", value: title)
      ) {
        div(.class("flex is-drawer-open:space-x-4")) {
          SVG(icon)
          span(.class("text-xl is-drawer-close:hidden")) {
            title
          }
        }
        if !hideIsComplete {
          div(.class("is-drawer-close:hidden")) {
            if isComplete {
              SVG(.badgeCheck)
            } else {
              SVG(.ban)
            }
          }
          .attributes(.class("text-green-400"), when: isComplete)
          .attributes(.class("text-error"), when: !isComplete)
        }
      }
      .attributes(.class("is-drawer-close:text-green-400"), when: isComplete)
      .attributes(.class("is-drawer-close:text-error"), when: !isComplete && !hideIsComplete)
    }

    private func row(
      title: String,
      icon: SVG.Key,
      route: SiteRoute.View,
      isComplete: Bool,
      hideIsComplete: Bool = false
    ) -> some HTML<HTMLTag.a> {
      row(
        title: title, icon: icon, href: SiteRoute.View.router.path(for: route),
        isComplete: isComplete, hideIsComplete: hideIsComplete
      )
    }
  }
}
