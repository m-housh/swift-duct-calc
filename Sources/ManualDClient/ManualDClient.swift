import Dependencies
import DependenciesMacros
import Logging
import ManualDCore

@DependencyClient
public struct ManualDClient: Sendable {
  public var ductSize: @Sendable (DuctSizeRequest) async throws -> DuctSizeResponse
  public var frictionRate: @Sendable (FrictionRateRequest) async throws -> FrictionRateResponse
  public var totalEffectiveLength: @Sendable (TotalEffectiveLengthRequest) async throws -> Int
  public var equivalentRectangularDuct:
    @Sendable (EquivalentRectangularDuctRequest) async throws -> EquivalentRectangularDuctResponse

  public func calculateSizes(
    rooms: [Room],
    trunks: [DuctSizing.TrunkSize],
    equipmentInfo: EquipmentInfo,
    maxSupplyLength: EffectiveLength,
    maxReturnLength: EffectiveLength,
    designFrictionRate: Double,
    projectSHR: Double,
    logger: Logger? = nil
  ) async throws -> (rooms: [DuctSizing.RoomContainer], trunks: [DuctSizing.TrunkContainer]) {
    try await (
      calculateSizes(
        rooms: rooms, equipmentInfo: equipmentInfo,
        maxSupplyLength: maxSupplyLength, maxReturnLength: maxReturnLength,
        designFrictionRate: designFrictionRate, projectSHR: projectSHR
      ),
      calculateSizes(
        rooms: rooms, trunks: trunks, equipmentInfo: equipmentInfo,
        maxSupplyLength: maxSupplyLength, maxReturnLength: maxReturnLength,
        designFrictionRate: designFrictionRate, projectSHR: projectSHR)
    )
  }

  func calculateSizes(
    rooms: [Room],
    equipmentInfo: EquipmentInfo,
    maxSupplyLength: EffectiveLength,
    maxReturnLength: EffectiveLength,
    designFrictionRate: Double,
    projectSHR: Double,
    logger: Logger? = nil
  ) async throws -> [DuctSizing.RoomContainer] {

    var registerIDCount = 1
    var retval: [DuctSizing.RoomContainer] = []
    let totalHeatingLoad = rooms.totalHeatingLoad
    let totalCoolingSensible = rooms.totalCoolingSensible(shr: projectSHR)

    for room in rooms {
      let heatingLoad = room.heatingLoadPerRegister
      let coolingLoad = room.coolingSensiblePerRegister(projectSHR: projectSHR)
      let heatingPercent = heatingLoad / totalHeatingLoad
      let coolingPercent = coolingLoad / totalCoolingSensible
      let heatingCFM = heatingPercent * Double(equipmentInfo.heatingCFM)
      let coolingCFM = coolingPercent * Double(equipmentInfo.coolingCFM)
      let designCFM = DuctSizing.DesignCFM(heating: heatingCFM, cooling: coolingCFM)
      let sizes = try await self.ductSize(
        .init(designCFM: Int(designCFM.value), frictionRate: designFrictionRate)
      )

      for n in 1...room.registerCount {

        var rectangularWidth: Int? = nil
        let rectangularSize = room.rectangularSizes?
          .first(where: { $0.register == nil || $0.register == n })

        if let rectangularSize {
          let response = try await self.equivalentRectangularDuct(
            .init(round: sizes.finalSize, height: rectangularSize.height)
          )
          rectangularWidth = response.width
        }

        retval.append(
          .init(
            registerID: "SR-\(registerIDCount)",
            roomID: room.id,
            roomName: "\(room.name)-\(n)",
            roomRegister: n,
            heatingLoad: heatingLoad,
            coolingLoad: coolingLoad,
            heatingCFM: heatingCFM,
            coolingCFM: coolingCFM,
            designCFM: designCFM,
            roundSize: sizes.ductulatorSize,
            finalSize: sizes.finalSize,
            velocity: sizes.velocity,
            flexSize: sizes.flexSize,
            rectangularSize: rectangularSize,
            rectangularWidth: rectangularWidth
          )
        )
        registerIDCount += 1
      }
    }

    return retval
  }

  func calculateSizes(
    rooms: [Room],
    trunks: [DuctSizing.TrunkSize],
    equipmentInfo: EquipmentInfo,
    maxSupplyLength: EffectiveLength,
    maxReturnLength: EffectiveLength,
    designFrictionRate: Double,
    projectSHR: Double,
    logger: Logger? = nil
  ) async throws -> [DuctSizing.TrunkContainer] {

    var retval = [DuctSizing.TrunkContainer]()
    let totalHeatingLoad = rooms.totalHeatingLoad
    let totalCoolingSensible = rooms.totalCoolingSensible(shr: projectSHR)

    for trunk in trunks {
      let heatingLoad = trunk.totalHeatingLoad
      let coolingLoad = trunk.totalCoolingSensible(projectSHR: projectSHR)
      let heatingPercent = heatingLoad / totalHeatingLoad
      let coolingPercent = coolingLoad / totalCoolingSensible
      let heatingCFM = heatingPercent * Double(equipmentInfo.heatingCFM)
      let coolingCFM = coolingPercent * Double(equipmentInfo.coolingCFM)
      let designCFM = DuctSizing.DesignCFM(heating: heatingCFM, cooling: coolingCFM)
      let sizes = try await self.ductSize(
        .init(designCFM: Int(designCFM.value), frictionRate: designFrictionRate)
      )
      var width: Int? = nil
      if let height = trunk.height {
        let rectangularSize = try await self.equivalentRectangularDuct(
          .init(round: sizes.finalSize, height: height)
        )
        width = rectangularSize.width
      }

      retval.append(
        .init(
          trunk: trunk,
          ductSize: .init(
            designCFM: designCFM,
            roundSize: sizes.ductulatorSize,
            finalSize: sizes.finalSize,
            velocity: sizes.velocity,
            flexSize: sizes.flexSize)
        )
      )
    }

    return retval
  }

}

extension ManualDClient: TestDependencyKey {
  public static let testValue = Self()
}

extension DependencyValues {
  public var manualD: ManualDClient {
    get { self[ManualDClient.self] }
    set { self[ManualDClient.self] = newValue }
  }
}

// MARK: Duct Size
extension ManualDClient {
  public struct DuctSizeRequest: Codable, Equatable, Sendable {
    public let designCFM: Int
    public let frictionRate: Double

    public init(
      designCFM: Int,
      frictionRate: Double
    ) {
      self.designCFM = designCFM
      self.frictionRate = frictionRate
    }
  }

  public struct DuctSizeResponse: Codable, Equatable, Sendable {

    public let ductulatorSize: Double
    public let finalSize: Int
    public let flexSize: Int
    public let velocity: Int

    public init(
      ductulatorSize: Double,
      finalSize: Int,
      flexSize: Int,
      velocity: Int
    ) {
      self.ductulatorSize = ductulatorSize
      self.finalSize = finalSize
      self.flexSize = flexSize
      self.velocity = velocity
    }
  }
}

// MARK: -  Friction Rate
extension ManualDClient {
  public struct FrictionRateRequest: Codable, Equatable, Sendable {

    public let externalStaticPressure: Double
    public let componentPressureLosses: [ComponentPressureLoss]
    public let totalEffectiveLength: Int

    public init(
      externalStaticPressure: Double,
      componentPressureLosses: [ComponentPressureLoss],
      totalEffectiveLength: Int
    ) {
      self.externalStaticPressure = externalStaticPressure
      self.componentPressureLosses = componentPressureLosses
      self.totalEffectiveLength = totalEffectiveLength
    }
  }

  public struct FrictionRateResponse: Codable, Equatable, Sendable {

    public let availableStaticPressure: Double
    public let frictionRate: Double

    public init(availableStaticPressure: Double, frictionRate: Double) {
      self.availableStaticPressure = availableStaticPressure
      self.frictionRate = frictionRate
    }
  }
}

// MARK: Total Effective Length
extension ManualDClient {
  public struct TotalEffectiveLengthRequest: Codable, Equatable, Sendable {

    public let trunkLengths: [Int]
    public let runoutLengths: [Int]
    public let effectiveLengthGroups: [EffectiveLengthGroup]

    public init(
      trunkLengths: [Int],
      runoutLengths: [Int],
      effectiveLengthGroups: [EffectiveLengthGroup]
    ) {
      self.trunkLengths = trunkLengths
      self.runoutLengths = runoutLengths
      self.effectiveLengthGroups = effectiveLengthGroups
    }
  }
}

// MARK: Equivalent Rectangular Duct
extension ManualDClient {
  public struct EquivalentRectangularDuctRequest: Codable, Equatable, Sendable {
    public let roundSize: Int
    public let height: Int

    public init(round roundSize: Int, height: Int) {
      self.roundSize = roundSize
      self.height = height
    }
  }

  public struct EquivalentRectangularDuctResponse: Codable, Equatable, Sendable {
    public let height: Int
    public let width: Int

    public init(height: Int, width: Int) {
      self.height = height
      self.width = width
    }
  }
}
