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
