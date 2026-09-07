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
    case .home, .login, .signup, .test, .ductulator, .fittings, .privacyPolicy:
      return nil
    case .project, .user:
      return viewRouteMiddleware
    }
  }
}
