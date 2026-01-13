import Dependencies
import Foundation

public enum DuctSizing {

  public struct RectangularDuct: Codable, Equatable, Identifiable, Sendable {

    public let id: UUID
    public let register: Int?
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

  public struct SizeContainer: Codable, Equatable, Sendable {

    public let designCFM: DesignCFM
    public let roundSize: Double
    public let finalSize: Int
    public let velocity: Int
    public let flexSize: Int
    public let height: Int?
    public let width: Int?

    public init(
      designCFM: DuctSizing.DesignCFM,
      roundSize: Double,
      finalSize: Int,
      velocity: Int,
      flexSize: Int,
      height: Int? = nil,
      width: Int? = nil
    ) {
      self.designCFM = designCFM
      self.roundSize = roundSize
      self.finalSize = finalSize
      self.velocity = velocity
      self.flexSize = flexSize
      self.height = height
      self.width = width
    }
  }

  public struct RoomContainer: Codable, Equatable, Sendable {

    public let registerID: String
    public let roomID: Room.ID
    public let roomName: String
    public let roomRegister: Int
    public let heatingLoad: Double
    public let coolingLoad: Double
    public let heatingCFM: Double
    public let coolingCFM: Double
    public let designCFM: DesignCFM
    public let roundSize: Double
    public let finalSize: Int
    public let velocity: Int
    public let flexSize: Int
    public let rectangularSize: RectangularDuct?
    public let rectangularWidth: Int?

    public init(
      registerID: String,
      roomID: Room.ID,
      roomName: String,
      roomRegister: Int,
      heatingLoad: Double,
      coolingLoad: Double,
      heatingCFM: Double,
      coolingCFM: Double,
      designCFM: DesignCFM,
      roundSize: Double,
      finalSize: Int,
      velocity: Int,
      flexSize: Int,
      rectangularSize: RectangularDuct? = nil,
      rectangularWidth: Int? = nil
    ) {
      self.registerID = registerID
      self.roomID = roomID
      self.roomName = roomName
      self.roomRegister = roomRegister
      self.heatingLoad = heatingLoad
      self.coolingLoad = coolingLoad
      self.heatingCFM = heatingCFM
      self.coolingCFM = coolingCFM
      self.designCFM = designCFM
      self.roundSize = roundSize
      self.finalSize = finalSize
      self.velocity = velocity
      self.flexSize = flexSize
      self.rectangularSize = rectangularSize
      self.rectangularWidth = rectangularWidth
    }
  }

  public enum DesignCFM: Codable, Equatable, Sendable {
    case heating(Double)
    case cooling(Double)

    public init(heating: Double, cooling: Double) {
      if heating >= cooling {
        self = .heating(heating)
      } else {
        self = .cooling(cooling)
      }
    }

    public var value: Double {
      switch self {
      case .heating(let value): return value
      case .cooling(let value): return value
      }
    }
  }
}

extension DuctSizing {

  public struct TrunkContainer: Codable, Equatable, Identifiable, Sendable {
    public var id: TrunkSize.ID { trunk.id }

    public let trunk: TrunkSize
    public let ductSize: SizeContainer

    public init(
      trunk: TrunkSize,
      ductSize: SizeContainer
    ) {
      self.trunk = trunk
      self.ductSize = ductSize
    }
  }

  public struct TrunkSize: Codable, Equatable, Identifiable, Sendable {

    public let id: UUID
    public let projectID: Project.ID
    public let type: TrunkType
    public let rooms: [RoomProxy]
    public let height: Int?

    public init(
      id: UUID,
      projectID: Project.ID,
      type: DuctSizing.TrunkSize.TrunkType,
      rooms: [DuctSizing.TrunkSize.RoomProxy],
      height: Int? = nil
    ) {
      self.id = id
      self.projectID = projectID
      self.type = type
      self.rooms = rooms
      self.height = height
    }
  }

}

extension DuctSizing.TrunkSize {
  public struct Create: Codable, Equatable, Sendable {

    public let projectID: Project.ID
    public let type: TrunkType
    public let rooms: [Room.ID: [Int]]
    public let height: Int?

    public init(
      projectID: Project.ID,
      type: DuctSizing.TrunkSize.TrunkType,
      rooms: [Room.ID: [Int]],
      height: Int? = nil
    ) {
      self.projectID = projectID
      self.type = type
      self.rooms = rooms
      self.height = height
    }
  }

  // TODO: Make registers non-optional
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
