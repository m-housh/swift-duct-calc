import DatabaseClient
import Fluent
import ManualDCore
import Vapor

// FIX: Remove these, not used currently.
extension DatabaseClient.Projects {

  func fetchPage(
    userID: User.ID,
    page: Int = 1,
    limit: Int = 25
  ) async throws -> Page<Project> {
    try await fetch(userID, .init(page: page, per: limit))
  }

  func fetchPage(
    userID: User.ID,
    page: PageRequest
  ) async throws -> Page<Project> {
    try await fetch(userID, page)
  }
}

extension DatabaseClient.ComponentLoss {

  func createDefaults(projectID: Project.ID) async throws {
    let defaults = ComponentPressureLoss.Create.default(projectID: projectID)
    for loss in defaults {
      _ = try await create(loss)
    }
  }
}

extension PageRequest {
  static func next<T>(_ currentPage: Page<T>) -> Self {
    .init(page: currentPage.metadata.page + 1, per: currentPage.metadata.per)
  }
}
