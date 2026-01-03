import Elementary
import ManualDCore

extension ViewController.Request {

  func render() async throws -> AnySendableHTML {
    switch route {
    case .login(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .project(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .room(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .frictionRate(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .effectiveLength(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .user(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    default:
      // FIX: FIX
      return _render(isHtmxRequest: false) {
        div { "Fix me!" }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    _render(isHtmxRequest: isHtmxRequest) {
      switch self {
      case .index:
        ProjectView(project: .mock)
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
      return _render(isHtmxRequest: isHtmxRequest, active: .rooms) {
        RoomsView(rooms: Room.mocks)
      }
    }
  }
}

extension SiteRoute.View.FrictionRateRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .index:
      return _render(isHtmxRequest: isHtmxRequest, active: .frictionRate) {
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
      return _render(isHtmxRequest: isHtmxRequest, active: .effectiveLength) {
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

extension SiteRoute.View.UserRoute {

  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    // case .login(.index):
    //   return _render(isHtmxRequest: isHtmxRequest, showSidebar: false) {
    //     LoginForm()
    //   }
    case .signup(.index):
      return _render(isHtmxRequest: isHtmxRequest, showSidebar: false) {
        LoginForm(style: .signup)
      }
    default:
      return div { "Fix Me!" }
    }
  }
}

extension SiteRoute.View.LoginRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    _render(isHtmxRequest: isHtmxRequest, showSidebar: false) {
      switch self {
      case .index:
        LoginForm()
      case .submit:
        // FIX:
        div { "Fix me!" }
      }
    }
  }
}

private func _render<C: HTML>(
  isHtmxRequest: Bool,
  active activeTab: Sidebar.ActiveTab = .projects,
  showSidebar: Bool = true,
  @HTMLBuilder inner: () -> C
) -> AnySendableHTML where C: Sendable {
  if isHtmxRequest {
    return inner()
  }
  return MainPage(
    active: activeTab,
    showSidebar: showSidebar
  ) {
    inner()
  }
}
