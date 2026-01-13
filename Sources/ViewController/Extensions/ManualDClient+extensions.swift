import Logging
import ManualDClient
import ManualDCore

extension ManualDClient {

  func calculate(
    rooms: [Room],
    trunks: [DuctSizing.TrunkSize],
    designFrictionRateResult: (EquipmentInfo, EffectiveLength.MaxContainer, Double)?,
    projectSHR: Double?,
    logger: Logger? = nil
  ) async throws -> (rooms: [DuctSizing.RoomContainer], trunks: [DuctSizing.TrunkContainer]) {
    guard let designFrictionRateResult else { return ([], []) }
    let equipmentInfo = designFrictionRateResult.0
    let effectiveLengths = designFrictionRateResult.1
    let designFrictionRate = designFrictionRateResult.2

    guard let maxSupply = effectiveLengths.supply else { return ([], []) }
    guard let maxReturn = effectiveLengths.return else { return ([], []) }

    let ductRooms = try await self.calculateSizes(
      rooms: rooms,
      trunks: trunks,
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
