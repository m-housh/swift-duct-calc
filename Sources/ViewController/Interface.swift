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

  public typealias AuthenticateHandler = @Sendable (User) -> Void
  public typealias CurrentUserHandler = @Sendable () throws -> User

  public var view: @Sendable (Request) async throws -> AnySendableHTML
}

extension ViewController {

  public struct Request: Sendable {

    public let route: SiteRoute.View
    public let isHtmxRequest: Bool
    public let logger: Logger
    public let authenticateUser: AuthenticateHandler
    public let currentUser: CurrentUserHandler

    public init(
      route: SiteRoute.View,
      isHtmxRequest: Bool,
      logger: Logger,
      authenticateUser: @escaping AuthenticateHandler,
      currentUser: @escaping CurrentUserHandler
    ) {
      self.route = route
      self.isHtmxRequest = isHtmxRequest
      self.logger = logger
      self.authenticateUser = authenticateUser
      self.currentUser = currentUser
    }

    func authenticate(_ user: User) {
      self.authenticateUser(user)
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
