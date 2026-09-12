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
    case .signup(.submitProfile(let form)):
      return viewRouteMiddleware + [ProfileOwnershipMiddleware(target: .user(form.userID))]
    case .user(.profile(.submit(let form))):
      return viewRouteMiddleware + [ProfileOwnershipMiddleware(target: .user(form.userID))]
    case .user(.profile(.update(let id, _))):
      return viewRouteMiddleware + [ProfileOwnershipMiddleware(target: .profile(id))]
    case .home, .login, .signup, .test, .ductulator, .privacyPolicy, .fittings, .fittingReference:
      return nil
    case .project(let route):
      switch route {
      case .detail(let id, let detail):
        return viewRouteMiddleware + [ProjectOwnershipMiddleware(projectID: id, detail: detail)]
      case .delete(let id), .update(let id, _):
        return viewRouteMiddleware + [ProjectOwnershipMiddleware(projectID: id)]
      default: return viewRouteMiddleware
      }
    case .user:
      return viewRouteMiddleware
    }
  }
}
