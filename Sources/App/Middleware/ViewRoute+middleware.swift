import DatabaseClient
import Fluent
import ManualDCore
import Vapor

private let viewRouteMiddleware: [any Middleware] = [
  UserPasswordAuthenticator(),
  UserSessionAuthenticator(),
  User.redirectMiddleware(path: "/login"),
]

extension SiteRoute.View {
  var middleware: [any Middleware]? {
    switch self {
    case .project,
      .frictionRate,
      .effectiveLength,
      .room:
      return viewRouteMiddleware
    case .login, .signup:
      return nil
    }
  }
}
