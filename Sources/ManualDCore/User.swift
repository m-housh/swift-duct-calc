import Dependencies
import Foundation

/// Represents a user of the site.
///
public struct User: Codable, Equatable, Identifiable, Sendable {

  /// The unique id of the user.
  public let id: UUID
  /// The user's email address.
  public let email: String
  /// When the user was created in the database.
  public let createdAt: Date
  /// When the user was updated in the database.
  public let updatedAt: Date

  public init(
    id: UUID,
    email: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.email = email
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension User {
  /// Represents the data required to create a new user.
  public struct Create: Codable, Equatable, Sendable {

    /// The user's email address.
    public let email: String
    /// The password for the user.
    public let password: String
    /// The password confirmation, must match the password.
    public let confirmPassword: String

    public init(
      email: String,
      password: String,
      confirmPassword: String
    ) {
      self.email = email
      self.password = password
      self.confirmPassword = confirmPassword
    }
  }

  /// Represents data required to login a user.
  public struct Login: Codable, Equatable, Sendable {
    /// The user's email address.
    public let email: String
    /// The password for the user.
    public let password: String
    /// An optional page / route to navigate to after logging in the user.
    public let next: String?

    public init(email: String, password: String, next: String? = nil) {
      self.email = email
      self.password = password
      self.next = next
    }
  }

  /// Represents a user session token, for a logged in user.
  public struct Token: Codable, Equatable, Identifiable, Sendable {
    /// The unique id of the token.
    public let id: UUID
    /// The user id the token is for.
    public let userID: User.ID
    /// The token value.
    public let value: String

    public init(id: UUID, userID: User.ID, value: String) {
      self.id = id
      self.userID = userID
      self.value = value
    }
  }
}

#if DEBUG

  extension User {
    public static var mock: Self {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now
      return .init(id: uuid(), email: "testy@example.com", createdAt: now, updatedAt: now)
    }
  }

#endif
