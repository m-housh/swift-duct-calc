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
    case .project, .user:
      return viewRouteMiddleware
    }
  }
}
