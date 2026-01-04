import Dependencies
import Foundation

public struct Room: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let projectID: Project.ID
  public let name: String
  public let heatingLoad: Double
  public let coolingLoad: Double
  public let registerCount: Int
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    name: String,
    heatingLoad: Double,
    coolingLoad: Double,
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

  public struct Create: Codable, Equatable, Sendable {
    public let projectID: Project.ID
    public let name: String
    public let heatingLoad: Double
    public let coolingLoad: Double
    public let registerCount: Int

    public init(
      projectID: Project.ID,
      name: String,
      heatingLoad: Double,
      coolingLoad: Double,
      registerCount: Int = 1
    ) {
      self.projectID = projectID
      self.name = name
      self.heatingLoad = heatingLoad
      self.coolingLoad = coolingLoad
      self.registerCount = registerCount
    }

    public init(
      form: Room.Form,
      projectID: Project.ID
    ) {
      self.init(
        projectID: projectID,
        name: form.name,
        heatingLoad: form.heatingLoad,
        coolingLoad: form.coolingLoad,
        registerCount: form.registerCount
      )
    }
  }

  public struct Form: Codable, Equatable, Sendable {
    public let name: String
    public let heatingLoad: Double
    public let coolingLoad: Double
    public let registerCount: Int

    public init(
      name: String,
      heatingLoad: Double,
      coolingLoad: Double,
      registerCount: Int
    ) {
      self.name = name
      self.heatingLoad = heatingLoad
      self.coolingLoad = coolingLoad
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
        name: "Kitchen",
        heatingLoad: 12345,
        coolingLoad: 1234,
        registerCount: 2,
        createdAt: Date(),
        updatedAt: Date()
      ),
      Room(
        id: UUID(1),
        projectID: UUID(1),
        name: "Bedroom - 1",
        heatingLoad: 12345,
        coolingLoad: 1456,
        registerCount: 1,
        createdAt: Date(),
        updatedAt: Date()
      ),
      Room(
        id: UUID(2),
        projectID: UUID(2),
        name: "Family Room",
        heatingLoad: 12345,
        coolingLoad: 1673,
        registerCount: 3,
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }

#endif
