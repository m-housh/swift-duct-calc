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
      zipCode: String
    ) {
      self.name = name
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
    }
  }
}
