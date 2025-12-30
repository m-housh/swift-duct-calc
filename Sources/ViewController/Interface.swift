import Dependencies
import DependenciesMacros
import Elementary
import Logging
import ManualDCore

extension DependencyValues {
  public var viewController: ViewController {
    get { self[ViewController.self] }
    set { self[ViewController.self] = newValue }
  }
}

public typealias AnySendableHTML = (any HTML & Sendable)

@DependencyClient
public struct ViewController: Sendable {
  public var view: @Sendable (Request) async throws -> AnySendableHTML
}

extension ViewController {

  public struct Request: Sendable {

    public let route: SiteRoute.View
    public let isHtmxRequest: Bool
    public let logger: Logger

    public init(
      route: SiteRoute.View,
      isHtmxRequest: Bool,
      logger: Logger
    ) {
      self.route = route
      self.isHtmxRequest = isHtmxRequest
      self.logger = logger
    }
  }
}

extension ViewController: DependencyKey {
  public static let testValue = Self()

  // FIX: Fix.
  public static let liveValue = Self(
    view: { request in
      try await request.render()
    }
  )
}
