import DatabaseClient
import Dependencies
import DependenciesMacros
import ManualDCore
import Vapor

extension DependencyValues {
  /// Authentication dependency, for handling authentication tasks.
  public var auth: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}

/// Represents authentication tasks that are used in the application.
@DependencyClient
public struct AuthClient: Sendable {
  /// Create a new user and log them in.
  public var createAndLogin: @Sendable (User.Create) async throws -> User
  /// Get the current user.
  public var currentUser: @Sendable () throws -> User
  /// Login a user.
  public var login: @Sendable (User.Login) async throws -> User
  /// Logout a user.
  public var logout: @Sendable () throws -> Void
}

extension AuthClient: TestDependencyKey {
  public static let testValue = Self()

  public static func live(on request: Request) -> Self {
    @Dependency(\.database) var database

    return .init(
      createAndLogin: { createForm in
        let user = try await database.users.create(createForm)
        _ = try await database.users.login(
          .init(email: createForm.email, password: createForm.password)
        )
        request.auth.login(user)
        request.session.authenticate(user)
        request.logger.debug("LOGGED IN: \(user.id)")
        return user
      },
      currentUser: {
        try request.auth.require(User.self)
      },
      login: { loginForm in
        let token = try await database.users.login(loginForm)
        let user = try await database.users.get(token.userID)!
        request.session.authenticate(user)
        request.logger.debug("LOGGED IN: \(user.id)")
        return user
      },
      logout: { request.auth.logout(User.self) }
    )
  }
}
