import Dependencies
import Foundation

public struct Room: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let projectID: Project.ID
  public let name: String
  public let heatingLoad: Double
  public let coolingTotal: Double
  public let coolingSensible: Double?
  public let registerCount: Int
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    name: String,
    heatingLoad: Double,
    coolingTotal: Double,
    coolingSensible: Double? = nil,
    registerCount: Int = 1,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.projectID = projectID
    self.name = name
    self.heatingLoad = heatingLoad
    self.coolingTotal = coolingTotal
    self.coolingSensible = coolingSensible
    self.registerCount = registerCount
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension Room {

  public struct Create: Codable, Equatable, Sendable {
    public let projectID: Project.ID
    public let name: String
    public let heatingLoad: Double
    public let coolingTotal: Double
    public let coolingSensible: Double?
    public let registerCount: Int

    public init(
      projectID: Project.ID,
      name: String,
      heatingLoad: Double,
      coolingTotal: Double,
      coolingSensible: Double? = nil,
      registerCount: Int = 1
    ) {
      self.projectID = projectID
      self.name = name
      self.heatingLoad = heatingLoad
      self.coolingTotal = coolingTotal
      self.coolingSensible = coolingSensible
      self.registerCount = registerCount
    }
  }

  public struct Update: Codable, Equatable, Sendable {
    public let name: String?
    public let heatingLoad: Double?
    public let coolingTotal: Double?
    public let coolingSensible: Double?
    public let registerCount: Int?

    public init(
      name: String? = nil,
      heatingLoad: Double? = nil,
      coolingTotal: Double? = nil,
      coolingSensible: Double? = nil,
      registerCount: Int? = nil
    ) {
      self.name = name
      self.heatingLoad = heatingLoad
      self.coolingTotal = coolingTotal
      self.coolingSensible = coolingSensible
      self.registerCount = registerCount
    }
  }
}

extension Array where Element == Room {

  public var totalHeatingLoad: Double {
    reduce(into: 0) { $0 += $1.heatingLoad }
  }

  public var totalCoolingLoad: Double {
    reduce(into: 0) { $0 += $1.coolingTotal }
  }

  public func totalCoolingSensible(shr: Double) -> Double {
    reduce(into: 0) {
      let sensible = $1.coolingSensible ?? ($1.coolingTotal * shr)
      $0 += sensible
    }
  }
}

#if DEBUG

  extension Room {
    public static let mocks = [
      Room(
        id: UUID(0),
        projectID: UUID(0),
        name: "Kitchen",
        heatingLoad: 12345,
        coolingTotal: 1234,
        registerCount: 2,
        createdAt: Date(),
        updatedAt: Date()
      ),
      Room(
        id: UUID(1),
        projectID: UUID(1),
        name: "Bedroom - 1",
        heatingLoad: 12345,
        coolingTotal: 1456,
        registerCount: 1,
        createdAt: Date(),
        updatedAt: Date()
      ),
      Room(
        id: UUID(2),
        projectID: UUID(2),
        name: "Family Room",
        heatingLoad: 12345,
        coolingTotal: 1673,
        registerCount: 3,
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }

#endif
