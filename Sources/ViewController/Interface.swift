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

  func authenticate(
    _ login: User.Login
  ) async throws -> User {
    @Dependency(\.database.users) var users
    let token = try await users.login(login)
    let user = try await users.get(token.userID)!
    authenticateUser(user)
    logger.debug("Logged in user: \(user.id)")
    return user
  }

  func createAndAuthenticate(
    _ signup: User.Create
  ) async throws -> User {
    @Dependency(\.database.users) var users
    let user = try await users.create(signup)
    let _ = try await users.login(
      .init(email: signup.email, password: signup.password)
    )
    authenticateUser(user)
    logger.debug("Created and logged in user: \(user.id)")
    return user
  }
}
