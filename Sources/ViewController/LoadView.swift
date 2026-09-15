import DatabaseClient
import Dependencies
import Elementary
import ManualDCore

extension ViewController.Request {
  /// Render a project tab, distinguishing failed writes from failed refreshes after a save.
  func projectTab<Content: HTML & Sendable>(
    _ projectID: Project.ID, _ tab: SiteRoute.View.ProjectRoute.DetailRoute.Tab,
    catching: (@Sendable () async throws -> Void)? = nil,
    completedSteps: Project.CompletedSteps? = nil,
    hasStepActions: Bool = true,
    @HTMLBuilder content: () async throws -> Content
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    return try await afterMutation(catching) {
      try await view(projectID: projectID) {
        let steps =
          if let completedSteps { completedSteps } else {
            try await database.projects.getCompletedSteps(projectID)
          }
        let content = try await content()
        return ProjectView(
          projectID: projectID, activeTab: tab, completedSteps: steps,
          hasStepActions: hasStepActions
        ) {
          content
        }
      }
    }
  }
}
