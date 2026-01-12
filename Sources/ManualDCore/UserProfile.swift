import Foundation

extension User {
  public struct Profile: Codable, Equatable, Identifiable, Sendable {

    public let id: UUID
    public let userID: User.ID
    public let firstName: String
    public let lastName: String
    public let theme: Theme?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
      id: UUID,
      userID: User.ID,
      firstName: String,
      lastName: String,
      theme: Theme? = nil,
      createdAt: Date,
      updatedAt: Date
    ) {
      self.id = id
      self.userID = userID
      self.firstName = firstName
      self.lastName = lastName
      self.theme = theme
      self.createdAt = createdAt
      self.updatedAt = updatedAt
    }
  }
}

extension User.Profile {

  public struct Create: Codable, Equatable, Sendable {
    public let userID: User.ID
    public let firstName: String
    public let lastName: String
    public let theme: Theme?

    public init(
      userID: User.ID,
      firstName: String,
      lastName: String,
      theme: Theme? = nil
    ) {
      self.userID = userID
      self.firstName = firstName
      self.lastName = lastName
      self.theme = theme
    }
  }

  public struct Update: Codable, Equatable, Sendable {
    public let firstName: String?
    public let lastName: String?
    public let theme: Theme?

    public init(
      firstName: String? = nil,
      lastName: String? = nil,
      theme: Theme? = nil
    ) {
      self.firstName = firstName
      self.lastName = lastName
      self.theme = theme
    }
  }
}
