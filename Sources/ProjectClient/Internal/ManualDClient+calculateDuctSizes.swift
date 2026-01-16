import Logging
import ManualDClient
import ManualDCore

// TODO: Remove Logger and use depedency logger.

extension ManualDClient {

  func calculateDuctSizes(
    rooms: [Room],
    trunks: [DuctSizing.TrunkSize],
    equipmentInfo: EquipmentInfo,
    maxSupplyLength: EffectiveLength,
    maxReturnLength: EffectiveLength,
    designFrictionRate: Double,
    projectSHR: Double,
    logger: Logger? = nil
  ) async throws -> ProjectClient.ProjectResponse {
    try await .init(
      rooms: calculateRoomSizes(
        rooms: rooms,
        equipmentInfo: equipmentInfo,
        maxSupplyLength: maxSupplyLength,
        maxReturnLength: maxReturnLength,
        designFrictionRate: designFrictionRate,
        projectSHR: projectSHR
      ),
      trunks: calculateTrunkSizes(
        rooms: rooms,
        trunks: trunks,
        equipmentInfo: equipmentInfo,
        maxSupplyLength: maxSupplyLength,
        maxReturnLength: maxReturnLength,
        designFrictionRate: designFrictionRate,
        projectSHR: projectSHR
      )
    )
  }

  func calculateRoomSizes(
    rooms: [Room],
    equipmentInfo: EquipmentInfo,
    maxSupplyLength: EffectiveLength,
    maxReturnLength: EffectiveLength,
    designFrictionRate: Double,
    projectSHR: Double,
    logger: Logger? = nil
  ) async throws -> [DuctSizing.RoomContainer] {

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
      }
    }

    return retval
  }

  func calculateTrunkSizes(
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
            flexSize: sizes.flexSize,
            height: trunk.height,
            width: width
          )
        )
      )
    }

    return retval
  }

}

extension Room {

  var heatingLoadPerRegister: Double {

    heatingLoad / Double(registerCount)
  }

  func coolingSensiblePerRegister(projectSHR: Double) -> Double {
    let sensible = coolingSensible ?? (coolingTotal * projectSHR)
    return sensible / Double(registerCount)
  }
}

extension DuctSizing.TrunkSize.RoomProxy {

  // We need to make sure if registers got removed after a trunk
  // was already made / saved that we do not include registers that
  // no longer exist.
  private var actualRegisterCount: Int {
    guard registers.count <= room.registerCount else {
      return room.registerCount
    }
    return registers.count
  }

  var totalHeatingLoad: Double {
    room.heatingLoadPerRegister * Double(actualRegisterCount)
  }

  func totalCoolingSensible(projectSHR: Double) -> Double {
    room.coolingSensiblePerRegister(projectSHR: projectSHR) * Double(actualRegisterCount)
  }
}

extension DuctSizing.TrunkSize {

  var totalHeatingLoad: Double {
    rooms.reduce(into: 0) { $0 += $1.totalHeatingLoad }
  }

  func totalCoolingSensible(projectSHR: Double) -> Double {
    rooms.reduce(into: 0) { $0 += $1.totalCoolingSensible(projectSHR: projectSHR) }
  }
}
