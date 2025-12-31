import Dependencies
import Foundation

public struct Room: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let projectID: Project.ID
  public let name: String
  public let heatingLoad: Double
  public let coolingLoad: CoolingLoad
  public let registerCount: Int
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    name: String,
    heatingLoad: Double,
    coolingLoad: CoolingLoad,
    registerCount: Int = 1,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.projectID = projectID
    self.name = name
    self.heatingLoad = heatingLoad
    self.coolingLoad = coolingLoad
    self.registerCount = registerCount
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension Room {

  // TODO: Maybe remove project ID, and make dependencies that retrieves current project id??
  public struct Create: Codable, Equatable, Sendable {
    public let projectID: Project.ID
    public let name: String
    public let heatingLoad: Double
    public let coolingTotal: Double
    public let coolingSensible: Double
    public let registerCount: Int

    public init(
      projectID: Project.ID,
      name: String,
      heatingLoad: Double,
      coolingTotal: Double,
      coolingSensible: Double,
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
}

#if DEBUG

  extension Room {
    public static let mocks = [
      Room(
        id: UUID(0),
        projectID: UUID(0),
        name: "Test",
        heatingLoad: 12345,
        coolingLoad: .init(total: 12345, sensible: 12345),
        registerCount: 2,
        createdAt: Date(),
        updatedAt: Date()
      ),
      Room(
        id: UUID(1),
        projectID: UUID(1),
        name: "Test",
        heatingLoad: 12345,
        coolingLoad: .init(total: 12345, sensible: 12345),
        registerCount: 2,
        createdAt: Date(),
        updatedAt: Date()
      ),
      Room(
        id: UUID(2),
        projectID: UUID(2),
        name: "Test",
        heatingLoad: 12345,
        coolingLoad: .init(total: 12345, sensible: 12345),
        registerCount: 2,
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }

#endif
