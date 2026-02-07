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

  /// The cooling load required for the room (from Manual-J).
  public let coolingLoad: CoolingLoad

  /// The number of registers for the room.
  public let registerCount: Int

  /// An optional room that the airflow is delegated to.
  public let delegatedTo: Room.ID?

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
    coolingLoad: CoolingLoad,
    registerCount: Int = 1,
    delegatedTo: Room.ID? = nil,
    rectangularSizes: [RectangularSize]? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.projectID = projectID
    self.name = name
    self.heatingLoad = heatingLoad
    self.coolingLoad = coolingLoad
    self.registerCount = registerCount
    self.delegatedTo = delegatedTo
    self.rectangularSizes = rectangularSizes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Represents the cooling load of a room.
  ///
  /// Generally only one of the values is provided by a Manual-J room x room
  /// calculation.
  ///
  public struct CoolingLoad: Codable, Equatable, Sendable {

    public let total: Double?
    public let sensible: Double?

    public init(total: Double? = nil, sensible: Double? = nil) {
      self.total = total
      self.sensible = sensible
    }

    /// Calculates the cooling load based on the shr.
    ///
    /// Generally Manual-J room x room loads provide either the total load or the
    /// sensible load, so this allows us to calculate whichever is not provided.
    public func ensured(shr: Double) throws -> (total: Double, sensible: Double) {
      switch (total, sensible) {
      case (.none, .none):
        throw CoolingLoadError("Both the total and sensible loads are nil.")
      case (.some(let total), .some(let sensible)):
        return (total, sensible)
      case (.some(let total), .none):
        return (total, total * shr)
      case (.none, .some(let sensible)):
        return (sensible / shr, sensible)
      }

    }
  }
}

extension Room {
  /// Represents the data required to create a new room for a project.
  public struct Create: Codable, Equatable, Sendable {
    /// A unique name for the room in the project.
    public let name: String

    /// The heating load required for the room (from Manual-J).
    public let heatingLoad: Double

    /// The total cooling load required for the room (from Manual-J).
    public let coolingTotal: Double?

    /// An optional sensible cooling load for the room.
    public let coolingSensible: Double?

    /// The number of registers for the room.
    public let registerCount: Int

    /// An optional room that this room delegates it's airflow to.
    public let delegatedTo: Room.ID?

    public var coolingLoad: Room.CoolingLoad {
      .init(total: coolingTotal, sensible: coolingSensible)
    }

    public init(
      name: String,
      heatingLoad: Double,
      coolingTotal: Double? = nil,
      coolingSensible: Double? = nil,
      registerCount: Int = 1,
      delegatedTo: Room.ID? = nil
    ) {
      self.name = name
      self.heatingLoad = heatingLoad
      self.coolingTotal = coolingTotal
      self.coolingSensible = coolingSensible
      self.registerCount = registerCount
      self.delegatedTo = delegatedTo
    }
  }

  public struct CSV: Equatable, Sendable {
    public let file: Data

    public init(file: Data) {
      self.file = file
    }

    /// Represents a row in a CSV file.
    ///
    /// This is similar to ``Room.Create``, but since the rooms are not yet
    /// created, delegating to another room is done via the room's name
    /// instead of id.
    ///
    public struct Row: Codable, Equatable, Sendable {

      /// A unique name for the room in the project.
      public let name: String

      /// The heating load required for the room (from Manual-J).
      public let heatingLoad: Double

      /// The total cooling load required for the room (from Manual-J).
      public let coolingTotal: Double?

      /// An optional sensible cooling load for the room.
      public let coolingSensible: Double?

      /// The number of registers for the room.
      public let registerCount: Int

      /// An optional room that this room delegates it's airflow to.
      public let delegatedToName: String?

      public init(
        name: String,
        heatingLoad: Double,
        coolingTotal: Double? = nil,
        coolingSensible: Double? = nil,
        registerCount: Int,
        delegatedToName: String? = nil
      ) {
        self.name = name
        self.heatingLoad = heatingLoad
        self.coolingTotal = coolingTotal
        self.coolingSensible = coolingSensible
        self.registerCount = registerCount
        self.delegatedToName = delegatedToName
      }
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
  /// Onlly fields that are supplied get updated.
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

    public var coolingLoad: CoolingLoad? {
      guard coolingTotal != nil || coolingSensible != nil else {
        return nil
      }
      return .init(total: coolingTotal, sensible: coolingSensible)
    }

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
  public func totalCoolingLoad(shr: Double) throws -> Double {
    try reduce(into: 0) { $0 += try $1.coolingLoad.ensured(shr: shr).total }
  }

  /// The sum of sensible cooling loads for an array of rooms.
  ///
  /// - Parameters:
  ///   - shr: The project wide sensible heat ratio.
  public func totalCoolingSensible(shr: Double) throws -> Double {
    try reduce(into: 0) {
      // let sensible = $1.coolingSensible ?? ($1.coolingTotal * shr)
      $0 += try $1.coolingLoad.ensured(shr: shr).sensible
    }
  }
}

public struct CoolingLoadError: Error, Equatable, Sendable {
  public let reason: String

  public init(_ reason: String) {
    self.reason = reason
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
          coolingLoad: .init(total: 2472),
          // coolingSensible: nil,
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
          coolingLoad: .init(total: 2916),
          // coolingSensible: nil,
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
          coolingLoad: .init(total: 7446),
          // coolingSensible: nil,
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
          coolingLoad: .init(total: 5096),
          // coolingSensible: nil,
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
          coolingLoad: .init(total: 6829),
          // coolingSensible: nil,
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
          coolingLoad: .init(total: 2076),
          // coolingSensible: nil,
          registerCount: 2,
          rectangularSizes: nil,
          createdAt: now,
          updatedAt: now
        ),
      ]
    }
  }

#endif
