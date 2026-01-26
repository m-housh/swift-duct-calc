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

    public func registerIDS(rooms: [RoomContainer]) -> [String] {
      trunk.rooms.reduce(into: []) { array, room in
        array = room.registers.reduce(into: array) { array, register in
          if let room =
            rooms
            .first(where: { $0.roomID == room.id && $0.roomRegister == register })
          {
            array.append(room.roomName)
          }
        }
      }
      .sorted()
    }
  }
}

#if DEBUG
  extension DuctSizes {
    public static func mock(
      equipmentInfo: EquipmentInfo,
      rooms: [Room],
      trunks: [TrunkSize]
    ) -> Self {

      let totalHeatingLoad = rooms.totalHeatingLoad
      let totalCoolingLoad = rooms.totalCoolingLoad

      let roomContainers = rooms.reduce(into: [RoomContainer]()) { array, room in
        array += RoomContainer.mock(
          room: room,
          totalHeatingLoad: totalHeatingLoad,
          totalCoolingLoad: totalCoolingLoad,
          totalHeatingCFM: Double(equipmentInfo.heatingCFM),
          totalCoolingCFM: Double(equipmentInfo.coolingCFM)
        )
      }

      return .init(
        rooms: roomContainers,
        trunks: TrunkContainer.mock(
          trunks: trunks,
          totalHeatingLoad: totalHeatingLoad,
          totalCoolingLoad: totalCoolingLoad,
          totalHeatingCFM: Double(equipmentInfo.heatingCFM),
          totalCoolingCFM: Double(equipmentInfo.coolingCFM)
        )
      )
    }
  }

  extension DuctSizes.RoomContainer {
    public static func mock(
      room: Room,
      totalHeatingLoad: Double,
      totalCoolingLoad: Double,
      totalHeatingCFM: Double,
      totalCoolingCFM: Double
    ) -> [Self] {
      var retval = [DuctSizes.RoomContainer]()
      let heatingLoad = room.heatingLoad / Double(room.registerCount)
      let heatingFraction = heatingLoad / totalHeatingLoad
      let heatingCFM = totalHeatingCFM * heatingFraction
      // Not really accurate, but works for mocks.
      let coolingLoad = room.coolingTotal / Double(room.registerCount)
      let coolingFraction = coolingLoad / totalCoolingLoad
      let coolingCFM = totalCoolingCFM * coolingFraction

      for n in 1...room.registerCount {

        retval.append(
          .init(
            roomID: room.id,
            roomName: room.name,
            roomRegister: n,
            heatingLoad: heatingLoad,
            coolingLoad: coolingLoad,
            heatingCFM: heatingCFM,
            coolingCFM: coolingCFM,
            ductSize: .init(
              rectangularID: nil,
              designCFM: .init(heating: heatingCFM, cooling: coolingCFM),
              roundSize: 7,
              finalSize: 8,
              velocity: 489,
              flexSize: 8,
              height: nil,
              width: nil
            )
          )
        )
      }
      return retval
    }

  }

  extension DuctSizes.TrunkContainer {

    public static func mock(
      trunks: [TrunkSize],
      totalHeatingLoad: Double,
      totalCoolingLoad: Double,
      totalHeatingCFM: Double,
      totalCoolingCFM: Double
    ) -> [Self] {
      trunks.reduce(into: []) { array, trunk in
        array.append(
          .init(
            trunk: trunk,
            ductSize: .init(
              designCFM: .init(heating: totalHeatingCFM, cooling: totalCoolingCFM),
              roundSize: 18,
              finalSize: 20,
              velocity: 987,
              flexSize: 20
            )
          )
        )
      }
    }
  }

#endif
