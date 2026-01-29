import Dependencies
import Foundation

extension User {
  /// Represents a user's profile. Which contains extra information about a user of the site.
  public struct Profile: Codable, Equatable, Identifiable, Sendable {

    /// The unique id of the profile
    public let id: UUID
    /// The user id the profile is for.
    public let userID: User.ID
    /// The user's first name.
    public let firstName: String
    /// The user's last name.
    public let lastName: String
    /// The user's company name.
    public let companyName: String
    /// The user's street address.
    public let streetAddress: String
    /// The user's city.
    public let city: String
    /// The user's state.
    public let state: String
    /// The user's zip code.
    public let zipCode: String
    /// An optional theme that the user prefers.
    public let theme: Theme?
    /// When the profile was created in the database.
    public let createdAt: Date
    /// When the profile was updated in the database.
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

  /// Represents the data required to create a user profile.
  public struct Create: Codable, Equatable, Sendable {
    /// The user id the profile is for.
    public let userID: User.ID
    /// The user's first name.
    public let firstName: String
    /// The user's last name.
    public let lastName: String
    /// The user's company name.
    public let companyName: String
    /// The user's street address.
    public let streetAddress: String
    /// The user's city.
    public let city: String
    /// The user's state.
    public let state: String
    /// The user's zip code.
    public let zipCode: String
    /// An optional theme that the user prefers.
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

  /// Represents the fields that can be updated on a user's profile.
  ///
  /// Only fields that are supplied get updated.
  public struct Update: Codable, Equatable, Sendable {
    /// The user's first name.
    public let firstName: String?
    /// The user's last name.
    public let lastName: String?
    /// The user's company name.
    public let companyName: String?
    /// The user's street address.
    public let streetAddress: String?
    /// The user's city.
    public let city: String?
    /// The user's state.
    public let state: String?
    /// The user's zip code.
    public let zipCode: String?
    /// An optional theme that the user prefers.
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

#if DEBUG
  extension User.Profile {
    public static func mock(userID: User.ID) -> Self {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now

      return .init(
        id: uuid(),
        userID: userID,
        firstName: "Testy",
        lastName: "McTestface",
        companyName: "Acme Co.",
        streetAddress: "1234 Sesame St",
        city: "Monroe",
        state: "OH",
        zipCode: "55555",
        createdAt: now,
        updatedAt: now
      )

    }
  }
#endif
