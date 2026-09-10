import DatabaseClient
import Dependencies
import ManualDClient
import ManualDCore

extension DatabaseClient {

  func calculateDuctSizes(
    details: Project.Detail
  ) async throws -> (DuctSizes, DuctSizeSharedRequest) {
    let (rooms, shared) = try await calculateRoomDuctSizes(details: details)
    return try await (
      .init(
        rooms: rooms,
        trunks: calculateTrunkDuctSizes(details: details, shared: shared)
      ),
      shared
    )
  }

  func calculateRoomDuctSizes(
    details: Project.Detail
  ) async throws -> (rooms: [DuctSizes.RoomContainer], shared: DuctSizeSharedRequest) {
    @Dependency(\.manualD) var manualD

    let shared = try sharedDuctRequest(details: details)
    let rooms = try await manualD.calculateRoomSizes(rooms: details.rooms, sharedRequest: shared)
    return (rooms, shared)
  }

  func calculateTrunkDuctSizes(
    details: Project.Detail,
    shared: DuctSizeSharedRequest? = nil
  ) async throws -> [DuctSizes.TrunkContainer] {
    @Dependency(\.manualD) var manualD

    let sharedRequest: DuctSizeSharedRequest
    if let shared {
      sharedRequest = shared
    } else {
      sharedRequest = try sharedDuctRequest(details: details)
    }

    return try await manualD.calculateTrunkSizes(
      rooms: details.rooms,
      trunks: details.trunks,
      sharedRequest: sharedRequest
    )
  }

  func sharedDuctRequest(details: Project.Detail) throws -> DuctSizeSharedRequest {
    let lengths = details.maxContainer
    var missing: [Project.DuctSizingUnavailable.Input] = []
    if details.equipmentInfo == nil { missing.append(.equipment) }
    if details.project.sensibleHeatRatio == nil { missing.append(.sensibleHeatRatio) }
    if details.rooms.isEmpty { missing.append(.rooms) }
    if lengths.supply == nil { missing.append(.supplyPath) }
    if lengths.return == nil { missing.append(.returnPath) }
    if details.componentLosses.isEmpty { missing.append(.componentLosses) }

    guard missing.isEmpty,
      let equipment = details.equipmentInfo,
      let shr = details.project.sensibleHeatRatio,
      let supply = lengths.supply,
      let returnLength = lengths.return
    else {
      throw Project.DuctSizingUnavailable(missingInputs: missing)
    }

    let availableStaticPressure = equipment.staticPressure - details.componentLosses.total
    let tel = supply.totalEquivalentLength + returnLength.totalEquivalentLength
    return .init(
      equipmentInfo: equipment,
      maxSupplyLength: supply,
      maxReturnLenght: returnLength,
      designFrictionRate: (availableStaticPressure * 100) / tel,
      projectSHR: shr
    )
  }
}
