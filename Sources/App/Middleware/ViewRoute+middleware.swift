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
    case .home, .login, .signup, .test, .quickCalc:
      return nil
    case .project, .user:
      return viewRouteMiddleware
    }
  }
}
