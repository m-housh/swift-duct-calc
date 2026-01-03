import DatabaseClient
import Dependencies
import Elementary
import Foundation
import ManualDCore

extension ViewController.Request {

  func render() async throws -> AnySendableHTML {

    @Dependency(\.database) var database

    switch route {
    case .login(let route):
      switch route {
      case .index:
        return try await _render(isHtmxRequest: isHtmxRequest, showSidebar: false) {
          LoginForm()
        }
      case .submit(let login):
        let token = try await database.users.login(login)
        let user = try await database.users.get(token.userID)!
        authenticate(user)
        let projects = try await database.projects.fetch(user.id, .init(page: 1, per: 25))
        return try await _render(isHtmxRequest: isHtmxRequest, showSidebar: false) {
          ProjectsTable(userID: user.id, projects: projects)
        }
      }
    case .signup(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .project(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .room(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .frictionRate(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .effectiveLength(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    // case .user(let route):
    //   return try await route.renderView(isHtmxRequest: isHtmxRequest)
    default:
      // FIX: FIX
      return try await _render(isHtmxRequest: false) {
        div { "Fix me!" }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute {

  private var shouldShowSidebar: Bool {
    switch self {
    case .index, .page: return false
    default: return true
    }
  }

  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    @Dependency(\.database.projects) var projects

    return try await _render(
      isHtmxRequest: isHtmxRequest,
      showSidebar: shouldShowSidebar
    ) {
      switch self {
      case .index:
        // ProjectView(project: .mock)
        let page = try await projects.fetch(UUID(0), .init(page: 1, per: 25))
        ProjectsTable(userID: UUID(0), projects: page)
      case .page(let page, let limit):
        let page = try await projects.fetch(UUID(0), .init(page: page, per: limit))
        ProjectsTable.Rows(projects: page)
      case .form(let dismiss):
        ProjectForm(dismiss: dismiss)
      case .create:
        div { "Fix me!" }
      }
    }
  }
}

extension SiteRoute.View.RoomRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .form(let dismiss):
      return RoomForm(dismiss: dismiss)
    case .index:
      return try await _render(isHtmxRequest: isHtmxRequest, active: .rooms) {
        RoomsView(rooms: Room.mocks)
      }
    }
  }
}

extension SiteRoute.View.FrictionRateRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .index:
      return try await _render(isHtmxRequest: isHtmxRequest, active: .frictionRate) {
        FrictionRateView()
      }
    case .form(let type, let dismiss):
      // FIX: Forms need to reference existing items.
      switch type {
      case .equipmentInfo:
        return EquipmentForm(dismiss: dismiss)
      case .componentPressureLoss:
        return ComponentLossForm(dismiss: dismiss)
      }
    }
  }
}

extension SiteRoute.View.FrictionRateRoute.FormType {
  var id: String {
    switch self {
    case .equipmentInfo:
      return "equipmentForm"
    case .componentPressureLoss:
      return "componentLossForm"
    }
  }
}

extension SiteRoute.View.EffectiveLengthRoute {

  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .index:
      return try await _render(isHtmxRequest: isHtmxRequest, active: .effectiveLength) {
        EffectiveLengthsView(effectiveLengths: EffectiveLength.mocks)
      }
    case .form(let dismiss):
      return EffectiveLengthForm(dismiss: dismiss)

    case .field(let type):
      switch type {
      case .straightLength:
        return StraightLengthField()
      case .group:
        return GroupField()
      }
    }
  }
}

extension SiteRoute.View.SignupRoute {

  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    @Dependency(\.database.users) var users

    switch self {
    case .index:
      return try await _render(isHtmxRequest: isHtmxRequest, showSidebar: false) {
        LoginForm(style: .signup)
      }
    case .submit(let request):
      _ = try await users.create(request)
      // FIX: We should just login the new user at this point.
      return try await _render(isHtmxRequest: isHtmxRequest, showSidebar: false) {
        LoginForm()
      }

    // default:
    //   return div { "Fix Me!" }
    }
  }
}

// extension SiteRoute.View.LoginRoute {
//   func renderView(on req: ViewController.Request) async throws -> AnySendableHTML {
//
//     @Dependency(\.database) var database
//
//     return try await _render(isHtmxRequest: req.isHtmxRequest, showSidebar: false) {
//       switch self {
//       case .index:
//         LoginForm()
//       case .submit(let login):
//         // FIX:
//         // div { "Logged in Success! Fix me!" }
//         let token = try await database.users.login(login)
//         let user = try await database.users.get(token.userID)!
//         _ = req.authenticate(user)
//         // req.authenticate(user)
//         let page = try await database.projects.fetch(user.id, .init(page: 1, per: 25))
//         ProjectsTable(userID: user.id, projects: page)
//       }
//     }
//   }
// }

private func _render<C: HTML>(
  isHtmxRequest: Bool,
  active activeTab: Sidebar.ActiveTab = .projects,
  showSidebar: Bool = true,
  @HTMLBuilder inner: () async throws -> C
) async throws -> AnySendableHTML where C: Sendable {
  let inner = try await inner()
  if isHtmxRequest {
    return inner
  }
  return MainPage(
    active: activeTab,
    showSidebar: showSidebar
  ) {
    inner
  }
}
