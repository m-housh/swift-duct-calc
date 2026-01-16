import DatabaseClient
import ManualDCore

extension DatabaseClient.ComponentLoss {

  func createDefaults(projectID: Project.ID) async throws {
    let defaults = ComponentPressureLoss.Create.default(projectID: projectID)
    for loss in defaults {
      _ = try await create(loss)
    }
  }
}
