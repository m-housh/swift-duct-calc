import Dependencies
import Foundation

/// Represents the equipment information for a project.
///
/// This is used in the friction rate worksheet and sizing ducts. It holds on to items
/// such as the target static pressure, cooling CFM, and heating CFM for the project.
public struct EquipmentInfo: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let projectID: Project.ID
  public let staticPressure: Double
  public let heatingCFM: Int
  public let coolingCFM: Int
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    staticPressure: Double = 0.5,
    heatingCFM: Int,
    coolingCFM: Int,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.projectID = projectID
    self.staticPressure = staticPressure
    self.heatingCFM = heatingCFM
    self.coolingCFM = coolingCFM
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension EquipmentInfo {

  // TODO: Remove projectID and use dependency to lookup current project ??
  public struct Create: Codable, Equatable, Sendable {
    public let projectID: Project.ID
    public let staticPressure: Double
    public let heatingCFM: Int
    public let coolingCFM: Int

    public init(
      projectID: Project.ID,
      staticPressure: Double = 0.5,
      heatingCFM: Int,
      coolingCFM: Int
    ) {
      self.projectID = projectID
      self.staticPressure = staticPressure
      self.heatingCFM = heatingCFM
      self.coolingCFM = coolingCFM
    }
  }

  public struct Update: Codable, Equatable, Sendable {
    public let staticPressure: Double?
    public let heatingCFM: Int?
    public let coolingCFM: Int?

    public init(
      staticPressure: Double? = nil,
      heatingCFM: Int? = nil,
      coolingCFM: Int? = nil
    ) {
      self.staticPressure = staticPressure
      self.heatingCFM = heatingCFM
      self.coolingCFM = coolingCFM
    }
  }
}

#if DEBUG
  extension EquipmentInfo {

    public static func mock(projectID: Project.ID) -> Self {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now

      return .init(
        id: uuid(),
        projectID: projectID,
        heatingCFM: 900,
        coolingCFM: 1000,
        createdAt: now,
        updatedAt: now
      )
    }

    public static let mock = Self(
      id: UUID(0),
      projectID: UUID(0),
      heatingCFM: 1000,
      coolingCFM: 1000,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
#endif
