import Elementary
import ManualDCore

extension ViewController.Request {

  func render() async throws -> AnySendableHTML {
    switch route {
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
      return mainPage
    }
  }
}

extension SiteRoute.View.ProjectRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .index:
      return MainPage(active: .projects) {
        ProjectView(project: .mock)
      }
    case .form(let dismiss):
      return ProjectForm(dismiss: dismiss)

    case .create:
      return mainPage
    }
  }
}

extension SiteRoute.View.RoomRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .form(let dismiss):
      return RoomForm(dismiss: dismiss)
    case .index:
      return MainPage(active: .rooms) {
        RoomsView(rooms: Room.mocks)
      }
    }
  }
}

extension SiteRoute.View.FrictionRateRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .index:
      return MainPage(active: .frictionRate) {
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
      return MainPage(active: .effectiveLength) {
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
    case .login(.index):
      return MainPage(active: .projects, showSidebar: false) {
        LoginForm()
      }
    case .signup(.index):
      return MainPage(active: .projects, showSidebar: false) {
        LoginForm(style: .signup)
      }
    default:
      return div { "Fix Me!" }
    }
  }
}

private let mainPage: AnySendableHTML = {
  MainPage(active: .projects) {
    div {
      h1 { "It works!" }
    }
  }
}()

@Sendable
private func render<C: HTML>(
  _ mainPage: (C) async throws -> AnySendableHTML,
  _ isHtmxRequest: Bool,
  @HTMLBuilder html: () -> C
) async rethrows -> AnySendableHTML where C: Sendable {
  guard isHtmxRequest else {
    return try await mainPage(html())
  }
  return html()
}

@Sendable
private func render<C: HTML>(
  _ mainPage: (C) async throws -> AnySendableHTML,
  _ isHtmxRequest: Bool,
  _ html: @autoclosure @escaping () -> C
) async rethrows -> AnySendableHTML where C: Sendable {
  try await render(mainPage, isHtmxRequest) { html() }
}
