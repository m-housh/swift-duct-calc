import Dependencies
import Foundation

// FIX: Remove username.
public struct User: Codable, Equatable, Identifiable, Sendable {

  public let id: UUID
  public let email: String
  public let username: String
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    email: String,
    username: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.username = username
    self.email = email
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension User {
  public struct Create: Codable, Equatable, Sendable {

    public let username: String
    public let email: String
    public let password: String
    public let confirmPassword: String

    public init(
      username: String,
      email: String,
      password: String,
      confirmPassword: String
    ) {
      self.username = username
      self.email = email
      self.password = password
      self.confirmPassword = confirmPassword
    }
  }

  public struct Login: Codable, Equatable, Sendable {
    public let email: String
    public let password: String
    public let next: String?

    public init(email: String, password: String, next: String? = nil) {
      self.email = email
      self.password = password
      self.next = next
    }
  }

  public struct Token: Codable, Equatable, Identifiable, Sendable {

    public let id: UUID
    public let userID: User.ID
    public let value: String

    public init(id: UUID, userID: User.ID, value: String) {
      self.id = id
      self.userID = userID
      self.value = value
    }
  }
}
