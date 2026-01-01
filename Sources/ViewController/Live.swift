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
      return MainPage {
        ProjectView(project: .mock)
      }
    case .form(let dismiss):
      guard !dismiss else {
        return div(.id("projectForm")) {}
      }
      return ProjectForm()

    case .create:
      return mainPage
    }
  }
}

extension SiteRoute.View.RoomRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .form(let dismiss):
      guard !dismiss else {
        return div(.id("roomForm")) {}
      }
      return RoomForm()
    case .index:
      return MainPage {
        RoomsView(rooms: Room.mocks)
      }
    }
  }
}

extension SiteRoute.View.FrictionRateRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .index:
      return MainPage {
        FrictionRateView()
      }
    case .form(let type, let dismiss):
      guard !dismiss else {
        return div(.id(type.id)) {}
      }
      // FIX: Forms need to reference existing items.
      switch type {
      case .equipmentInfo:
        return EquipmentForm()
      case .componentPressureLoss:
        return ComponentLossForm()
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

private let mainPage: AnySendableHTML = {
  MainPage {
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
