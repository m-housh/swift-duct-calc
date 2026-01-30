import Dependencies
import Foundation

/// Represents trunk calculations for a project.
///
/// These are used to size trunk ducts / runs for multiple rooms or registers.
public struct TrunkSize: Codable, Equatable, Identifiable, Sendable {

  /// The unique identifier of the trunk size.
  public let id: UUID
  /// The project the trunk size is for.
  public let projectID: Project.ID
  /// The type of the trunk size (supply or return).
  public let type: TrunkType
  /// The rooms / registers associated with the trunk size.
  public let rooms: [RoomProxy]
  /// An optional rectangular height used to calculate the equivalent
  /// rectangular size of the trunk.
  public let height: Int?
  /// An optional name / label used for identifying the trunk.
  public let name: String?

  public init(
    id: UUID,
    projectID: Project.ID,
    type: TrunkType,
    rooms: [RoomProxy],
    height: Int? = nil,
    name: String? = nil
  ) {
    self.id = id
    self.projectID = projectID
    self.type = type
    self.rooms = rooms
    self.height = height
    self.name = name
  }
}

extension TrunkSize {
  /// Represents the data needed to create a new ``TrunkSize`` in the database.
  public struct Create: Codable, Equatable, Sendable {

    /// The project the trunk size is for.
    public let projectID: Project.ID
    /// The type of the trunk size (supply or return).
    public let type: TrunkType
    /// The rooms / registers associated with the trunk size.
    public let rooms: [Room.ID: [Int]]
    /// An optional rectangular height used to calculate the equivalent
    /// rectangular size of the trunk.
    public let height: Int?
    /// An optional name / label used for identifying the trunk.
    public let name: String?

    public init(
      projectID: Project.ID,
      type: TrunkType,
      rooms: [Room.ID: [Int]],
      height: Int? = nil,
      name: String? = nil
    ) {
      self.projectID = projectID
      self.type = type
      self.rooms = rooms
      self.height = height
      self.name = name
    }
  }

  /// Represents the fields that can be updated on a ``TrunkSize`` in the database.
  ///
  /// Only supplied fields are updated.
  public struct Update: Codable, Equatable, Sendable {

    /// The type of the trunk size (supply or return).
    public let type: TrunkType?
    /// The rooms / registers associated with the trunk size.
    public let rooms: [Room.ID: [Int]]?
    /// An optional rectangular height used to calculate the equivalent
    /// rectangular size of the trunk.
    public let height: Int?
    /// An optional name / label used for identifying the trunk.
    public let name: String?

    public init(
      type: TrunkType? = nil,
      rooms: [Room.ID: [Int]]? = nil,
      height: Int? = nil,
      name: String? = nil
    ) {
      self.type = type
      self.rooms = rooms
      self.height = height
      self.name = name
    }
  }

  /// A container / wrapper around a ``Room`` that is used with a ``TrunkSize``.
  ///
  /// This is needed because a room can have multiple registers and it is possible
  /// that a trunk does not serve all registers in that room.
  @dynamicMemberLookup
  public struct RoomProxy: Codable, Equatable, Sendable {

    /// The room associated with the ``TrunkSize``.
    public let room: Room
    /// The specific room registers associated with the ``TrunkSize``.
    public let registers: [Int]

    public init(room: Room, registers: [Int]) {
      self.room = room
      self.registers = registers
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<Room, T>) -> T {
      room[keyPath: keyPath]
    }
  }

  /// Represents the type of a ``TrunkSize``, either supply or return.
  public enum TrunkType: String, CaseIterable, Codable, Equatable, Sendable {
    case `return`
    case supply

    public static let allCases = [Self.supply, .return]
  }
}

#if DEBUG
  extension TrunkSize {
    public static func mock(projectID: Project.ID, rooms: [Room]) -> [Self] {
      @Dependency(\.uuid) var uuid

      let allRooms = rooms.reduce(into: [TrunkSize.RoomProxy]()) { array, room in
        var registers = [Int]()
        for n in 1...room.registerCount {
          registers.append(n)
        }
        array.append(.init(room: room, registers: registers))
      }

      return [
        .init(id: uuid(), projectID: projectID, type: .supply, rooms: allRooms),
        .init(id: uuid(), projectID: projectID, type: .return, rooms: allRooms),
      ]
    }
  }
#endif
