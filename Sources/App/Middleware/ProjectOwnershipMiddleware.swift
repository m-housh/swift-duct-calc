import DatabaseClient
import ManualDCore
import Vapor

/// Protects every project entry point, including PDF generation and project deletion.
struct ProjectOwnershipMiddleware: AsyncMiddleware {
  let projectID: Project.ID

  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    let user = try request.auth.require(User.self)
    let database = DatabaseClient.live(database: request.db)
    guard try await database.projects.getForUser(projectID, user.id) != nil else {
      throw Abort(.notFound)
    }
    return try await next.respond(to: request)
  }
}
