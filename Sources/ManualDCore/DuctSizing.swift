import Dependencies
import Foundation

public enum DuctSizing {

  public struct RectangularDuct: Codable, Equatable, Sendable {

    public let register: Int?
    public let height: Int

    public init(
      register: Int? = nil,
      height: Int,
    ) {
      self.register = register
      self.height = height
    }

  }

  public struct RoomContainer: Codable, Equatable, Sendable {

    public let registerID: String
    public let roomID: Room.ID
    public let roomName: String
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
