import AuthClient
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
      await request.render()
    }
  )
}

extension ViewController.Request {

  func currentUser() throws -> User {
    @Dependency(\.auth.currentUser) var currentUser
    return try currentUser()
  }

  func authenticate(
    _ login: User.Login
  ) async throws -> User {
    @Dependency(\.auth) var auth
    return try await auth.login(login)
  }

  @discardableResult
  func createAndAuthenticate(
    _ signup: User.Create
  ) async throws -> User {
    @Dependency(\.auth) var auth
    return try await auth.createAndLogin(signup)
  }
}
