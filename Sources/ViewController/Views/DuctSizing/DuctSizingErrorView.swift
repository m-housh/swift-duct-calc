import Elementary
import ManualDCore
import Styleguide

struct DuctSizingErrorView: HTML, Sendable {
  @Environment(ProjectViewValue.$projectID) var projectID

  let error: any Error

  var body: some HTML {
    div(.class("space-y-4")) {
      PageTitle("Duct Sizes")
      if let unavailable = error as? Project.DuctSizingUnavailable {
        div(.role("alert"), .class("space-y-2")) {
          p { "Complete these inputs to calculate duct sizes:" }
          ul(.class("list-disc pl-6 space-y-2")) {
            for input in unavailable.missingInputs {
              li {
                a(.class("link"), .href(route: .project(.detail(projectID, route(for: input))))) {
                  input.rawValue
                }
              }
            }
          }
        }
      } else {
        ErrorView(error: error)
      }
    }
  }

  private func route(for input: Project.DuctSizingUnavailable.Input)
    -> SiteRoute.View.ProjectRoute.DetailRoute
  {
    switch input {
    case .equipment: .equipment(.index)
    case .sensibleHeatRatio, .rooms: .rooms(.index)
    case .supplyPath, .returnPath: .equivalentLength(.index)
    case .componentLosses: .frictionRate(.index)
    }
  }
}
