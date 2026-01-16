import DatabaseClient
import Dependencies
import ManualDClient
import ManualDCore

extension DatabaseClient {

  func calculateDuctSizes(
    projectID: Project.ID
  ) async throws -> ProjectClient.DuctSizeResponse {
    @Dependency(\.manualD) var manualD

    return try await manualD.calculateDuctSizes(
      rooms: rooms.fetch(projectID),
      trunks: trunkSizes.fetch(projectID),
      sharedRequest: sharedDuctRequest(projectID)
    )
  }

  func calculateRoomDuctSizes(
    projectID: Project.ID
  ) async throws -> [DuctSizing.RoomContainer] {
    @Dependency(\.manualD) var manualD

    return try await manualD.calculateRoomSizes(
      rooms: rooms.fetch(projectID),
      sharedRequest: sharedDuctRequest(projectID)
    )
  }

  func calculateTrunkDuctSizes(
    projectID: Project.ID
  ) async throws -> [DuctSizing.TrunkContainer] {
    @Dependency(\.manualD) var manualD

    return try await manualD.calculateTrunkSizes(
      rooms: rooms.fetch(projectID),
      trunks: trunkSizes.fetch(projectID),
      sharedRequest: sharedDuctRequest(projectID)
    )
  }

  func sharedDuctRequest(_ projectID: Project.ID) async throws -> DuctSizeSharedRequest {

    guard let dfrResponse = try await designFrictionRate(projectID: projectID) else {
      throw DuctCalcClientError("Project not complete.")
    }

    let ensuredTEL = try dfrResponse.ensureMaxContainer()

    return try await .init(
      equipmentInfo: dfrResponse.equipmentInfo,
      maxSupplyLength: ensuredTEL.supply,
      maxReturnLenght: ensuredTEL.return,
      designFrictionRate: dfrResponse.designFrictionRate,
      projectSHR: ensuredSHR(projectID)
    )

  }

  // Fetches the project sensible heat ratio or throws an error if it's nil.
  func ensuredSHR(_ projectID: Project.ID) async throws -> Double {
    guard let projectSHR = try await projects.getSensibleHeatRatio(projectID) else {
      throw DuctCalcClientError("Project sensible heat ratio not set.")
    }
    return projectSHR
  }

  // Internal container.
  struct DesignFrictionRateResponse: Equatable, Sendable {

    typealias EnsuredTEL = (supply: EffectiveLength, return: EffectiveLength)

    let designFrictionRate: Double
    let equipmentInfo: EquipmentInfo
    let telMaxContainer: EffectiveLength.MaxContainer

    func ensureMaxContainer() throws -> EnsuredTEL {

      guard let maxSupplyLength = telMaxContainer.supply else {
        throw DuctCalcClientError("Max supply TEL not found")
      }
      guard let maxReturnLength = telMaxContainer.return else {
        throw DuctCalcClientError("Max supply TEL not found")
      }

      return (maxSupplyLength, maxReturnLength)

    }
  }

  func designFrictionRate(
    projectID: Project.ID
  ) async throws -> DesignFrictionRateResponse? {
    guard let equipmentInfo = try await equipment.fetch(projectID) else {
      return nil
    }

    let equivalentLengths = try await effectiveLength.fetchMax(projectID)
    guard let tel = equivalentLengths.total else { return nil }

    let componentLosses = try await componentLoss.fetch(projectID)
    guard componentLosses.count > 0 else { return nil }

    let availableStaticPressure =
      equipmentInfo.staticPressure - componentLosses.total

    return .init(
      designFrictionRate: (availableStaticPressure * 100) / tel,
      equipmentInfo: equipmentInfo,
      telMaxContainer: equivalentLengths
    )
  }
}
