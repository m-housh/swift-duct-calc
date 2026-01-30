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
    let projectSHR = try details.project.ensuredSHR()

    guard
      let dfrResponse = designFrictionRate(
        componentLosses: details.componentLosses,
        equipmentInfo: details.equipmentInfo,
        equivalentLengths: details.maxContainer
      )
    else {
      throw ProjectClientError("Project not complete.")
    }

    let ensuredTEL = try dfrResponse.ensureMaxContainer()

    return .init(
      equipmentInfo: dfrResponse.equipmentInfo,
      maxSupplyLength: ensuredTEL.supply,
      maxReturnLenght: ensuredTEL.return,
      designFrictionRate: dfrResponse.designFrictionRate,
      projectSHR: projectSHR
    )
  }

  // Internal container.
  struct DesignFrictionRateResponse: Equatable, Sendable {

    typealias EnsuredTEL = (supply: EquivalentLength, return: EquivalentLength)

    let designFrictionRate: Double
    let equipmentInfo: EquipmentInfo
    let telMaxContainer: EquivalentLength.MaxContainer

    func ensureMaxContainer() throws -> EnsuredTEL {

      guard let maxSupplyLength = telMaxContainer.supply else {
        throw ProjectClientError("Max supply TEL not found")
      }
      guard let maxReturnLength = telMaxContainer.return else {
        throw ProjectClientError("Max supply TEL not found")
      }

      return (maxSupplyLength, maxReturnLength)

    }
  }

  func designFrictionRate(
    componentLosses: [ComponentPressureLoss],
    equipmentInfo: EquipmentInfo,
    equivalentLengths: EquivalentLength.MaxContainer
  ) -> DesignFrictionRateResponse? {
    guard let tel = equivalentLengths.totalEquivalentLength,
      componentLosses.count > 0
    else { return nil }

    let availableStaticPressure = equipmentInfo.staticPressure - componentLosses.total

    return .init(
      designFrictionRate: (availableStaticPressure * 100) / tel,
      equipmentInfo: equipmentInfo,
      telMaxContainer: equivalentLengths
    )

  }

}

extension Project {
  func ensuredSHR() throws -> Double {
    guard let shr = sensibleHeatRatio else {
      throw ProjectClientError("Sensible heat ratio not set on project id: \(id)")
    }
    return shr
  }
}
