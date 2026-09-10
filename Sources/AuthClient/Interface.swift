import DatabaseClient
import Dependencies
import DependenciesMacros
import ManualDCore
import Vapor

/// A transient success flag, consumed by aggregate middleware without retaining account data.
public struct SignupMetricKey: StorageKey {
  public typealias Value = Bool
}

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
  /// Whether the currently authenticated account has administrator access.
  public var isAdministrator: @Sendable () async -> Bool = { false }
  /// Login a user.
  public var login: @Sendable (User.Login) async throws -> User
  /// Logout a user.
  public var logout: @Sendable () throws -> Void
}

extension AuthClient: TestDependencyKey {
  public static let testValue = Self()

  public static func live(
    on request: Request,
    isAdministrator: @escaping @Sendable (User.ID) async -> Bool = { _ in false }
  ) -> Self {
    @Dependency(\.database) var database

    return .init(
      createAndLogin: { createForm in
        let user = try await database.users.create(createForm)
        request.storage[SignupMetricKey.self] = true
        _ = try await database.users.login(
          .init(email: createForm.email, password: createForm.password)
        )
        request.auth.login(user)
        request.session.authenticate(user)
        return user
      },
      currentUser: {
        try request.auth.require(User.self)
      },
      isAdministrator: {
        guard let user = request.auth.get(User.self) else { return false }
        return await isAdministrator(user.id)
      },
      login: { loginForm in
        let token = try await database.users.login(loginForm)
        let user = try await database.users.get(token.userID)!
        request.auth.login(user)
        request.session.authenticate(user)
        return user
      },
      logout: {
        request.session.destroy()
        request.auth.logout(User.self)
      }
    )
  }
}
