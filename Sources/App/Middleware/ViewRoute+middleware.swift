import DatabaseClient
import Fluent
import ManualDCore
import Vapor

private let viewRouteMiddleware: [any Middleware] = [
  UserPasswordAuthenticator(),
  User.redirectMiddleware { req in
    "/login?next=\(req.url.string)"
  },
]

extension SiteRoute.View {
  var middleware: [any Middleware]? {
    switch self {
    case .fittings(.review), .fittings(.saveReview):
      return viewRouteMiddleware
    case .home, .login, .signup, .test, .ductulator, .privacyPolicy, .fittings, .fittingReference:
      return nil
    case .project(let route):
      switch route {
      case .detail(let id, _), .delete(let id), .update(let id, _):
        return viewRouteMiddleware + [ProjectOwnershipMiddleware(projectID: id)]
      default: return viewRouteMiddleware
      }
    case .user:
      return viewRouteMiddleware
    }
  }
}
