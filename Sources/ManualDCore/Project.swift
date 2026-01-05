import Dependencies
import Foundation

public struct Project: Codable, Equatable, Identifiable, Sendable {

  public let id: UUID
  public let name: String
  public let streetAddress: String
  public let city: String
  public let state: String
  public let zipCode: String
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    name: String,
    streetAddress: String,
    city: String,
    state: String,
    zipCode: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.streetAddress = streetAddress
    self.city = city
    self.state = state
    self.zipCode = zipCode
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension Project {

  public struct Create: Codable, Equatable, Sendable {

    public let name: String
    public let streetAddress: String
    public let city: String
    public let state: String
    public let zipCode: String

    public init(
      name: String,
      streetAddress: String,
      city: String,
      state: String,
      zipCode: String,
    ) {
      self.name = name
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
    }
  }

  public struct Update: Codable, Equatable, Sendable {

    public let id: Project.ID
    public let name: String?
    public let streetAddress: String?
    public let city: String?
    public let state: String?
    public let zipCode: String?

    public init(
      id: Project.ID,
      name: String? = nil,
      streetAddress: String? = nil,
      city: String? = nil,
      state: String? = nil,
      zipCode: String? = nil
    ) {
      self.id = id
      self.name = name
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
    }
  }
}

#if DEBUG

  extension Project {
    public static let mock = Self(
      id: UUID(0),
      name: "Testy McTestface",
      streetAddress: "1234 Sesame Street",
      city: "Monroe",
      state: "OH",
      zipCode: "55555",
      createdAt: Date(),
      updatedAt: Date()
    )
  }

#endif
