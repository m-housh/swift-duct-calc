import DatabaseClient
import Dependencies
import ManualDClient
import ManualDCore

extension DatabaseClient {

  func calculateDuctSizes(
    projectID: Project.ID
  ) async throws -> (DuctSizes, DuctSizeSharedRequest, [Room]) {
    @Dependency(\.manualD) var manualD

    let shared = try await sharedDuctRequest(projectID)
    let rooms = try await rooms.fetch(projectID)

    return try await (
      manualD.calculateDuctSizes(
        rooms: rooms,
        trunks: trunkSizes.fetch(projectID),
        sharedRequest: shared
      ),
      shared,
      rooms
    )
  }

  func calculateRoomDuctSizes(
    projectID: Project.ID
  ) async throws -> ([DuctSizes.RoomContainer], DuctSizeSharedRequest) {
    @Dependency(\.manualD) var manualD

    let shared = try await sharedDuctRequest(projectID)

    return try await (
      manualD.calculateRoomSizes(
        rooms: rooms.fetch(projectID),
        sharedRequest: shared
      ),
      shared
    )
  }

  func calculateTrunkDuctSizes(
    projectID: Project.ID
  ) async throws -> ([DuctSizes.TrunkContainer], DuctSizeSharedRequest) {
    @Dependency(\.manualD) var manualD

    let shared = try await sharedDuctRequest(projectID)

    return try await (
      manualD.calculateTrunkSizes(
        rooms: rooms.fetch(projectID),
        trunks: trunkSizes.fetch(projectID),
        sharedRequest: shared
      ),
      shared
    )
  }

  func sharedDuctRequest(_ projectID: Project.ID) async throws -> DuctSizeSharedRequest {

    guard let dfrResponse = try await designFrictionRate(projectID: projectID) else {
      throw ProjectClientError("Project not complete.")
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
      throw ProjectClientError("Project sensible heat ratio not set.")
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
        throw ProjectClientError("Max supply TEL not found")
      }
      guard let maxReturnLength = telMaxContainer.return else {
        throw ProjectClientError("Max supply TEL not found")
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
