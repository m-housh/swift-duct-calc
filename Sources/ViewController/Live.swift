import Elementary
import ManualDCore

extension ViewController.Request {

  func render() async throws -> AnySendableHTML {
    switch route {
    case .project(let route):
      return try await route.renderView(isHtmxRequest: isHtmxRequest)
    case .room(let route):
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
        ProjectForm()
      }
    case .form:
      return MainPage {
        ProjectForm()
      }
    case .create:
      return mainPage
    }
  }
}

extension SiteRoute.View.RoomRoute {
  func renderView(isHtmxRequest: Bool) async throws -> AnySendableHTML {
    switch self {
    case .form:
      // TODO: Check that it's an htmx request.
      return RoomForm()
    case .index:
      return MainPage {
        div {
          RoomTable(rooms: Room.mocks)
        }
      }
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
