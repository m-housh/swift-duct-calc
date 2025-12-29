import Foundation

public struct ComponentPressureLoss: Codable, Equatable, Identifiable, Sendable {

  public let id: UUID
  public let projectID: Project.ID
  public let name: String
  public let value: Double
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    name: String,
    value: Double,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.projectID = projectID
    self.name = name
    self.value = value
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension ComponentPressureLoss {
  public struct Create: Codable, Equatable, Sendable {

    public let projectID: Project.ID
    public let name: String
    public let value: Double

    public init(
      projectID: Project.ID,
      name: String,
      value: Double,
    ) {
      self.projectID = projectID
      self.name = name
      self.value = value
    }
  }
}

public typealias ComponentPressureLosses = [String: Double]

#if DEBUG
  extension ComponentPressureLosses {
    public static var mock: Self {
      [
        "evaporator-coil": 0.2,
        "filter": 0.1,
        "supply-outlet": 0.03,
        "return-grille": 0.03,
        "balancing-damper": 0.03,
      ]
    }
  }
#endif
