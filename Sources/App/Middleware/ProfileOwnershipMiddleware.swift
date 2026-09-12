import DatabaseClient
import ManualDCore
import Vapor

struct ProfileOwnershipMiddleware: AsyncMiddleware {
  enum Target {
    case user(User.ID)
    case profile(User.Profile.ID)
  }
  let target: Target

  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    let user = try request.auth.require(User.self)
    let ownerID: User.ID?
    switch target {
    case .user(let id): ownerID = id
    case .profile(let id):
      ownerID = try await DatabaseClient.live(database: request.db).userProfiles.get(id)?.userID
    }
    guard ownerID == user.id else { throw Abort(.notFound) }
    return try await next.respond(to: request)
  }
}
