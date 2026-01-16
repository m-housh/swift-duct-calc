import Dependencies
import Foundation

public struct DuctSizes: Codable, Equatable, Sendable {

  public let rooms: [RoomContainer]
  public let trunks: [TrunkContainer]

  public init(
    rooms: [DuctSizes.RoomContainer],
    trunks: [DuctSizes.TrunkContainer]
  ) {
    self.rooms = rooms
    self.trunks = trunks
  }
}

extension DuctSizes {

  public struct SizeContainer: Codable, Equatable, Sendable {

    public let rectangularID: Room.RectangularSize.ID?
    public let designCFM: DesignCFM
    public let roundSize: Double
    public let finalSize: Int
    public let velocity: Int
    public let flexSize: Int
    public let height: Int?
    public let width: Int?

    public init(
      rectangularID: Room.RectangularSize.ID? = nil,
      designCFM: DuctSizes.DesignCFM,
      roundSize: Double,
      finalSize: Int,
      velocity: Int,
      flexSize: Int,
      height: Int? = nil,
      width: Int? = nil
    ) {
      self.rectangularID = rectangularID
      self.designCFM = designCFM
      self.roundSize = roundSize
      self.finalSize = finalSize
      self.velocity = velocity
      self.flexSize = flexSize
      self.height = height
      self.width = width
    }
  }

  @dynamicMemberLookup
  public struct RoomContainer: Codable, Equatable, Sendable {

    public let roomID: Room.ID
    public let roomName: String
    public let roomRegister: Int
    public let heatingLoad: Double
    public let coolingLoad: Double
    public let heatingCFM: Double
    public let coolingCFM: Double
    public let ductSize: SizeContainer

    public init(
      roomID: Room.ID,
      roomName: String,
      roomRegister: Int,
      heatingLoad: Double,
      coolingLoad: Double,
      heatingCFM: Double,
      coolingCFM: Double,
      ductSize: SizeContainer
    ) {
      self.roomID = roomID
      self.roomName = roomName
      self.roomRegister = roomRegister
      self.heatingLoad = heatingLoad
      self.coolingLoad = coolingLoad
      self.heatingCFM = heatingCFM
      self.coolingCFM = coolingCFM
      self.ductSize = ductSize
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DuctSizes.SizeContainer, T>) -> T {
      ductSize[keyPath: keyPath]
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

extension DuctSizes {

  // Represents the database model that the duct sizes have been calculated
  // for.
  @dynamicMemberLookup
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

    public subscript<T>(dynamicMember keyPath: KeyPath<TrunkSize, T>) -> T {
      trunk[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DuctSizes.SizeContainer, T>) -> T {
      ductSize[keyPath: keyPath]
    }
  }
}
