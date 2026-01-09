import Logging
import ManualDClient
import ManualDCore

extension ManualDClient {

  func calculate(
    rooms: [Room],
    designFrictionRateResult: (EquipmentInfo, EffectiveLength.MaxContainer, Double)?,
    projectSHR: Double?,
    logger: Logger? = nil
  ) async throws -> [DuctSizing.RoomContainer] {
    guard let designFrictionRateResult else { return [] }
    let equipmentInfo = designFrictionRateResult.0
    let effectiveLengths = designFrictionRateResult.1
    let designFrictionRate = designFrictionRateResult.2

    guard let maxSupply = effectiveLengths.supply else { return [] }
    guard let maxReturn = effectiveLengths.return else { return [] }

    let ductRooms = try await self.calculateSizes(
      rooms: rooms,
      equipmentInfo: equipmentInfo,
      maxSupplyLength: maxSupply,
      maxReturnLength: maxReturn,
      designFrictionRate: designFrictionRate,
      projectSHR: projectSHR ?? 1.0,
      logger: logger
    )

    // logger?.debug("Rooms: \(ductRooms)")

    return ductRooms

  }
}
