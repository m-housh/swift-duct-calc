import DatabaseClient
import Fluent
import ManualDCore
import Vapor

private let viewRouteMiddleware: [any Middleware] = [
  UserPasswordAuthenticator(),
  UserSessionAuthenticator(),
  User.redirectMiddleware { req in
    "/login?next=\(req.url.string)"
  },
]

extension SiteRoute.View {
  var middleware: [any Middleware]? {
    switch self {
    // TODO: Should pdf require authentication, just here now for testing.
    case .project(.detail(_, .pdf)), .login, .signup, .test:
      return nil
    case .project, .user:
      return viewRouteMiddleware
    }
  }
}
