import Elementary
import ManualDCore

/// Sample screens use the app's styles and views. The frame sandbox and inert content prevent edits.
struct HomePreviewPage: SendableHTMLDocument {
  let step: HomePreviewStep
  var title: String { "\(step.title) · DuctCalc sample project" }
  var lang: String { "en" }

  var head: some HTML {
    meta(.charset(.utf8))
    meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
    meta(.name("robots"), .content("noindex, nofollow"))
    link(.rel(.stylesheet), .href("/css/output.css"))
    link(.rel(.stylesheet), .href("/css/htmx.css"))
    link(.rel(.stylesheet), .href("/css/accessibility.css"))
    link(.rel(.stylesheet), .href("/css/project-workspace.css"))
    style {
      """
      html, body { margin: 0; overflow: hidden; }
      .project-workspace .app-navbar { display: none; }
      .project-workspace .project-layout { min-height: 100vh; }
      """
    }
  }

  var body: some HTML {
    div(.custom(name: "inert", value: "")) {
      ProjectView(
        projectID: HomePreviewData.project.id, activeTab: activeTab,
        completedSteps: .init(
          equipmentInfo: true, rooms: true, equivalentLength: true, frictionRate: true),
        project: HomePreviewData.project
      ) { previewContent }
      .environment(ProjectViewValue.$navigation, nil)
      .environment(AdminViewValue.$isAdministrator, false)
    }
  }

  private var activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab {
    switch step {
    case .rooms: .rooms
    case .equipment: .equipment
    case .paths: .equivalentLength
    case .pressure: .frictionRate
    case .sizes: .ductSizing
    }
  }

  @HTMLBuilder
  private var previewContent: some HTML & Sendable {
    switch step {
    case .rooms:
      RoomsView(rooms: HomePreviewData.rooms, sensibleHeatRatio: 0.83)
    case .equipment:
      EquipmentInfoView(
        equipmentInfo: HomePreviewData.equipment, projectID: HomePreviewData.project.id,
        readOnly: true)
    case .paths:
      EffectiveLengthsView(effectiveLengths: HomePreviewData.paths, coolingCFM: 1200)
    case .pressure:
      FrictionRateView(
        componentLosses: HomePreviewData.losses,
        equivalentLengths: .init(
          supply: HomePreviewData.paths[0], return: HomePreviewData.paths[1]),
        frictionRate: HomePreviewData.frictionRate, blowerStatic: 0.5,
        airflow: HomePreviewData.equipment.largerAirflow)
    case .sizes:
      DuctSizingView(ductSizes: HomePreviewData.ductSizes, readOnly: true)
    }
  }
}
