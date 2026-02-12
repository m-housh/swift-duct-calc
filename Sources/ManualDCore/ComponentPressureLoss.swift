import Dependencies
import Foundation

/// Represents component pressure losses used in the friction rate worksheet.
///
/// These are items such as filter, evaporator-coils, balance-dampers, etc. that
/// need to be overcome by the system fan.
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

    /// Commonly used default component pressure losses.
    public static func `default`(projectID: Project.ID) -> [Self] {
      [
        .init(projectID: projectID, name: "supply-outlet", value: 0.03),
        .init(projectID: projectID, name: "return-grille", value: 0.03),
        .init(projectID: projectID, name: "balancing-damper", value: 0.03),
      ]
    }
  }

  public struct Update: Codable, Equatable, Sendable {

    public let name: String?
    public let value: Double?

    public init(
      name: String? = nil,
      value: Double? = nil
    ) {
      self.name = name
      self.value = value
    }
  }
}

extension Array where Element == ComponentPressureLoss {
  public var total: Double {
    reduce(into: 0) { $0 += $1.value }
  }
}

#if DEBUG

  extension Array where Element == ComponentPressureLoss {
    public static func mock(projectID: Project.ID) -> Self {
      ComponentPressureLoss.mock(projectID: projectID)
    }
  }

  extension ComponentPressureLoss {
    public static func mock(projectID: Project.ID) -> [Self] {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now

      return [
        .init(
          id: uuid(),
          projectID: projectID,
          name: "evaporator-coil",
          value: 0.2,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "filter",
          value: 0.1,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "supply-outlet",
          value: 0.03,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "return-grille",
          value: 0.03,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "balancing-damper",
          value: 0.03,
          createdAt: now,
          updatedAt: now
        ),
      ]
    }

    public static var mock: [Self] {
      [
        .init(
          id: UUID(0),
          projectID: UUID(0),
          name: "evaporator-coil",
          value: 0.2,
          createdAt: Date(),
          updatedAt: Date()
        ),
        .init(
          id: UUID(1),
          projectID: UUID(0),
          name: "filter",
          value: 0.1,
          createdAt: Date(),
          updatedAt: Date()
        ),
        .init(
          id: UUID(2),
          projectID: UUID(0),
          name: "supply-outlet",
          value: 0.03,
          createdAt: Date(),
          updatedAt: Date()
        ),
        .init(
          id: UUID(3),
          projectID: UUID(0),
          name: "return-grille",
          value: 0.03,
          createdAt: Date(),
          updatedAt: Date()
        ),
        .init(
          id: UUID(4),
          projectID: UUID(0),
          name: "balance-damper",
          value: 0.03,
          createdAt: Date(),
          updatedAt: Date()
        ),
      ]
    }
  }
#endif
