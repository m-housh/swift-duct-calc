import Foundation

extension User {
  public struct Profile: Codable, Equatable, Identifiable, Sendable {

    public let id: UUID
    public let userID: User.ID
    public let firstName: String
    public let lastName: String
    public let companyName: String
    public let streetAddress: String
    public let city: String
    public let state: String
    public let zipCode: String
    public let theme: Theme?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
      id: UUID,
      userID: User.ID,
      firstName: String,
      lastName: String,
      companyName: String,
      streetAddress: String,
      city: String,
      state: String,
      zipCode: String,
      theme: Theme? = nil,
      createdAt: Date,
      updatedAt: Date
    ) {
      self.id = id
      self.userID = userID
      self.firstName = firstName
      self.lastName = lastName
      self.companyName = companyName
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
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
    public let companyName: String
    public let streetAddress: String
    public let city: String
    public let state: String
    public let zipCode: String
    public let theme: Theme?

    public init(
      userID: User.ID,
      firstName: String,
      lastName: String,
      companyName: String,
      streetAddress: String,
      city: String,
      state: String,
      zipCode: String,
      theme: Theme? = nil
    ) {
      self.userID = userID
      self.firstName = firstName
      self.lastName = lastName
      self.companyName = companyName
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
      self.theme = theme
    }
  }

  public struct Update: Codable, Equatable, Sendable {
    public let firstName: String?
    public let lastName: String?
    public let companyName: String?
    public let streetAddress: String?
    public let city: String?
    public let state: String?
    public let zipCode: String?
    public let theme: Theme?

    public init(
      firstName: String? = nil,
      lastName: String? = nil,
      companyName: String? = nil,
      streetAddress: String? = nil,
      city: String? = nil,
      state: String? = nil,
      zipCode: String? = nil,
      theme: Theme? = nil
    ) {
      self.firstName = firstName
      self.lastName = lastName
      self.companyName = companyName
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
      self.theme = theme
    }
  }
}
