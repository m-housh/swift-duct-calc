import DatabaseClient
import Dependencies
import Elementary
import ElementaryHTMX
import Logging
import ManualDClient
import ManualDCore
import Styleguide

enum ProjectViewValue {
  @TaskLocal static var projectID = Project.ID(0)
}

struct ProjectView: HTML, Sendable {
  @Dependency(\.database) var database
  @Dependency(\.manualD) var manualD

  let projectID: Project.ID
  let activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab
  let logger: Logger?

  init(
    projectID: Project.ID,
    activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab,
    logger: Logger? = nil
  ) {
    self.projectID = projectID
    self.activeTab = activeTab
    self.logger = logger
  }

  var body: some HTML {
    div(.class("h-screen w-full")) {

      div(.class("drawer lg:drawer-open")) {
        input(.id("my-drawer-1"), .type(.checkbox), .class("drawer-toggle"))

        div(.class("drawer-content")) {
          Navbar(sidebarToggle: true)
          div(.class("p-4")) {
            switch self.activeTab {
            case .project:
              await resultView(projectID) {
                guard let project = try await database.projects.get(projectID) else {
                  throw NotFoundError()
                }
                return project
              } onSuccess: { project in
                ProjectDetail(project: project)
              }
            case .equipment:
              await resultView(projectID) {
                try await database.equipment.fetch(projectID)
              } onSuccess: { equipment in
                EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
              }
            // FIX:
            // div { "Fix Me" }
            case .rooms:
              await resultView(projectID) {
                try await (
                  database.rooms.fetch(projectID),
                  database.projects.getSensibleHeatRatio(projectID)
                )
              } onSuccess: { (rooms, shr) in
                RoomsView(rooms: rooms, sensibleHeatRatio: shr)
              }

            case .equivalentLength:
              await resultView(projectID) {
                try await database.effectiveLength.fetch(projectID)
              } onSuccess: {
                EffectiveLengthsView(effectiveLengths: $0)
              }
            case .frictionRate:

              await resultView(projectID) {

                let equipmentInfo = try await database.equipment.fetch(projectID)
                let componentLosses = try await database.componentLoss.fetch(projectID)
                let equivalentLengths = try await database.effectiveLength.fetchMax(projectID)
                let frictionRateResponse = try await manualD.frictionRate(
                  equipmentInfo: equipmentInfo,
                  componentLosses: componentLosses,
                  effectiveLength: equivalentLengths
                )
                return (
                  equipmentInfo, componentLosses, equivalentLengths, frictionRateResponse
                )
              } onSuccess: {
                FrictionRateView(
                  equipmentInfo: $0.0,
                  componentLosses: $0.1,
                  equivalentLengths: $0.2,
                  frictionRateResponse: $0.3
                )
              }
            case .ductSizing:
              await resultView(projectID) {
                try await database.calculateDuctSizes(projectID: projectID)
              } onSuccess: {
                DuctSizingView(rooms: $0)
              }
            }
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

  func resultView<V: Sendable, E: Error, ValueView: HTML>(
    _ projectID: Project.ID,
    catching: @escaping @Sendable () async throws(E) -> V,
    onSuccess: @escaping @Sendable (V) -> ValueView
  ) async -> ResultView<V, E, _ModifiedTaskLocal<Project.ID, ValueView>, ErrorView<E>>
  where
    ValueView: Sendable, E: Sendable
  {
    await .init(
      result: .init(catching: catching),
      onSuccess: { result in
        onSuccess(result)
          .environment(ProjectViewValue.$projectID, projectID)
      }
    )
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
            flex min-h-full flex-col items-start bg-base-300 text-base-content
            is-drawer-close:min-w-[80px] is-drawer-open:max-w-[300px]
            """
          )
        ) {

          ul(.class("w-full")) {

            // FIX: Move to user profile / settings page.
            li(.class("w-full is-drawer-close:hidden")) {
              div(.class("flex justify-between p-4")) {
                Label("Theme")
                input(.type(.checkbox), .class("toggle theme-controller"), .value("light"))
              }
            }

            li(.class("flex w-full")) {
              row(
                title: "Project",
                icon: .mapPin,
                route: .project(.detail(projectID, .index(tab: .project))),
                isComplete: true
              )
              .attributes(.data("active", value: "true"), when: active == .project)
            }

            li(.class("w-full")) {
              row(
                title: "Rooms",
                icon: .doorClosed,
                route: .project(.detail(projectID, .rooms(.index))),
                isComplete: completedSteps.rooms
              )
              .attributes(.data("active", value: "true"), when: active == .rooms)
            }

            li(.class("flex w-full")) {
              row(
                title: "Equipment",
                icon: .fan,
                route: .project(.detail(projectID, .equipment(.index))),
                isComplete: completedSteps.equipmentInfo
              )
              .attributes(.data("active", value: "true"), when: active == .equipment)
            }

            li(.class("w-full")) {
              // Tooltip("Equivalent Lengths", position: .right) {
              row(
                title: "T.E.L.",
                icon: .rulerDimensionLine,
                route: .project(.detail(projectID, .equivalentLength(.index))),
                isComplete: completedSteps.equivalentLength
              )
              .attributes(.data("active", value: "true"), when: active == .equivalentLength)
              // }

            }
            li(.class("w-full")) {
              row(
                title: "Friction Rate",
                icon: .squareFunction,
                route: .project(.detail(projectID, .frictionRate(.index))),
                isComplete: completedSteps.frictionRate
              )
              .attributes(.data("active", value: "true"), when: active == .frictionRate)

            }
            li(.class("w-full")) {
              row(
                title: "Duct Sizes",
                icon: .wind,
                route: .project(.detail(projectID, .ductSizing(.index))),
                isComplete: false,
                hideIsComplete: true
              )
              .attributes(.data("active", value: "true"), when: active == .ductSizing)
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
    ) -> some HTML<HTMLTag.button> {
      button(
        .class(
          """
          w-full gap-1 py-2 border-b-1 border-gray-200
          hover:bg-neutral data-active:bg-neutral
          hover:text-white data-active:text-white
          is-drawer-open:flex is-drawer-open:space-x-4
          is-drawer-close:grid-cols-1
          """
        ),
        .hx.get(href),
        .hx.pushURL(true),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {
        div(
          .class(
            """
            w-full p-2 gap-1
            is-drawer-open:flex is-drawer-open:space-x-4
            is-drawer-close:grid-cols-1
            """
          )
        ) {
          div(
            .class(
              """
              items-center
              is-drawer-open:justify-start is-drawer-open:flex is-drawer-open:space-x-4
              is-drawer-close:justify-center is-drawer-close:mx-auto is-drawer-close:space-y-2
              """
            )
          ) {
            div(.class("flex items-center justify-center")) {
              SVG(icon)
            }
            .attributes(.class("is-drawer-close:text-green-400"), when: isComplete)
            .attributes(.class("is-drawer-close:text-error"), when: !isComplete && !hideIsComplete)

            div(.class("flex items-center justify-center")) {
              span { title }
            }
          }

          if !hideIsComplete {
            div(.class("flex grow justify-end items-end is-drawer-close:hidden")) {
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
      }
    }

    private func row(
      title: String,
      icon: SVG.Key,
      route: SiteRoute.View,
      isComplete: Bool,
      hideIsComplete: Bool = false
    ) -> some HTML<HTMLTag.button> {
      row(
        title: title, icon: icon, href: SiteRoute.View.router.path(for: route),
        isComplete: isComplete, hideIsComplete: hideIsComplete
      )
    }
  }
}

extension ManualDClient {

  func frictionRate(
    equipmentInfo: EquipmentInfo?,
    componentLosses: [ComponentPressureLoss],
    effectiveLength: EffectiveLength.MaxContainer
  ) async throws -> FrictionRateResponse? {
    guard let staticPressure = equipmentInfo?.staticPressure else {
      return nil
    }
    guard let totalEquivalentLength = effectiveLength.total else {
      return nil
    }
    return try await self.frictionRate(
      .init(
        externalStaticPressure: staticPressure,
        componentPressureLosses: componentLosses,
        totalEffectiveLength: Int(totalEquivalentLength)
      )
    )
  }

}
