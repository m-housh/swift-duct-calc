import Dependencies
import Foundation

// Represents the database model.
public struct TrunkSize: Codable, Equatable, Identifiable, Sendable {

  public let id: UUID
  public let projectID: Project.ID
  public let type: TrunkType
  public let rooms: [RoomProxy]
  public let height: Int?
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
  public struct Create: Codable, Equatable, Sendable {

    public let projectID: Project.ID
    public let type: TrunkType
    public let rooms: [Room.ID: [Int]]
    public let height: Int?
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

  public struct Update: Codable, Equatable, Sendable {

    public let type: TrunkType?
    public let rooms: [Room.ID: [Int]]?
    public let height: Int?
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

  public struct RoomProxy: Codable, Equatable, Identifiable, Sendable {

    public var id: Room.ID { room.id }
    public let room: Room
    public let registers: [Int]

    public init(room: Room, registers: [Int]) {
      self.room = room
      self.registers = registers
    }
  }

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
