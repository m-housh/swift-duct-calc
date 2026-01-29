import Dependencies
import Foundation

/// Represents a room in a project.
///
/// This contains data such as the heating and cooling load for the
/// room, the number of registers in the room, and any rectangular
/// duct size calculations stored for the room.
public struct Room: Codable, Equatable, Identifiable, Sendable {
  /// The unique id of the room.
  public let id: UUID
  /// The project this room is associated with.
  public let projectID: Project.ID
  /// A unique name for the room in the project.
  public let name: String
  /// The heating load required for the room (from Manual-J).
  public let heatingLoad: Double
  /// The total cooling load required for the room (from Manual-J).
  public let coolingTotal: Double
  /// An optional sensible cooling load for the room.
  ///
  /// **NOTE:** This is generally not set, but calculated from the project wide
  ///           sensible heat ratio.
  public let coolingSensible: Double?
  /// The number of registers for the room.
  public let registerCount: Int
  /// The rectangular duct size calculations for a room.
  ///
  /// **NOTE:** These are optionally set after the round sizes have been calculate
  ///           for a room.
  public let rectangularSizes: [RectangularSize]?
  /// When the room was created in the database.
  public let createdAt: Date
  /// When the room was updated in the database.
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    name: String,
    heatingLoad: Double,
    coolingTotal: Double,
    coolingSensible: Double? = nil,
    registerCount: Int = 1,
    rectangularSizes: [RectangularSize]? = nil,
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
    self.rectangularSizes = rectangularSizes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension Room {
  /// Represents the data required to create a new room for a project.
  public struct Create: Codable, Equatable, Sendable {
    /// The project this room is associated with.
    public let projectID: Project.ID
    /// A unique name for the room in the project.
    public let name: String
    /// The heating load required for the room (from Manual-J).
    public let heatingLoad: Double
    /// The total cooling load required for the room (from Manual-J).
    public let coolingTotal: Double
    /// An optional sensible cooling load for the room.
    public let coolingSensible: Double?
    /// The number of registers for the room.
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

  /// Represents a rectangular size calculation that is stored in the
  /// database for a given room.
  ///
  /// These are done after the round duct sizes have been calculated and
  /// can be used to calculate the equivalent rectangular size for a given run.
  public struct RectangularSize: Codable, Equatable, Identifiable, Sendable {
    /// The unique id of the rectangular size.
    public let id: UUID
    /// The register the rectangular size is associated with.
    public let register: Int?
    /// The height of the rectangular size, the width gets calculated.
    public let height: Int

    public init(
      id: UUID = .init(),
      register: Int? = nil,
      height: Int,
    ) {
      self.id = id
      self.register = register
      self.height = height
    }
  }

  /// Represents field that can be updated on a room after it's been created in the database.
  ///
  /// Only fields that are supplied get updated.
  public struct Update: Codable, Equatable, Sendable {
    /// A unique name for the room in the project.
    public let name: String?
    /// The heating load required for the room (from Manual-J).
    public let heatingLoad: Double?
    /// The total cooling load required for the room (from Manual-J).
    public let coolingTotal: Double?
    /// An optional sensible cooling load for the room.
    public let coolingSensible: Double?
    /// The number of registers for the room.
    public let registerCount: Int?
    /// The rectangular duct size calculations for a room.
    public let rectangularSizes: [RectangularSize]?

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
      self.rectangularSizes = nil
    }

    public init(
      rectangularSizes: [RectangularSize]
    ) {
      self.name = nil
      self.heatingLoad = nil
      self.coolingTotal = nil
      self.coolingSensible = nil
      self.registerCount = nil
      self.rectangularSizes = rectangularSizes
    }
  }
}

extension Array where Element == Room {

  /// The sum of heating loads for an array of rooms.
  public var totalHeatingLoad: Double {
    reduce(into: 0) { $0 += $1.heatingLoad }
  }

  /// The sum of total cooling loads for an array of rooms.
  public var totalCoolingLoad: Double {
    reduce(into: 0) { $0 += $1.coolingTotal }
  }

  /// The sum of sensible cooling loads for an array of rooms.
  ///
  /// - Parameters:
  ///   - shr: The project wide sensible heat ratio.
  public func totalCoolingSensible(shr: Double) -> Double {
    reduce(into: 0) {
      let sensible = $1.coolingSensible ?? ($1.coolingTotal * shr)
      $0 += sensible
    }
  }
}

#if DEBUG

  extension Room {

    public static func mock(projectID: Project.ID) -> [Self] {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now

      return [
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Bed-1",
          heatingLoad: 3913,
          coolingTotal: 2472,
          coolingSensible: nil,
          registerCount: 1,
          rectangularSizes: nil,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Entry",
          heatingLoad: 8284,
          coolingTotal: 2916,
          coolingSensible: nil,
          registerCount: 2,
          rectangularSizes: nil,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Family Room",
          heatingLoad: 9785,
          coolingTotal: 7446,
          coolingSensible: nil,
          registerCount: 3,
          rectangularSizes: nil,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Kitchen",
          heatingLoad: 4518,
          coolingTotal: 5096,
          coolingSensible: nil,
          registerCount: 2,
          rectangularSizes: nil,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Living Room",
          heatingLoad: 7553,
          coolingTotal: 6829,
          coolingSensible: nil,
          registerCount: 2,
          rectangularSizes: nil,
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Master",
          heatingLoad: 8202,
          coolingTotal: 2076,
          coolingSensible: nil,
          registerCount: 2,
          rectangularSizes: nil,
          createdAt: now,
          updatedAt: now
        ),
      ]
    }
  }

#endif
