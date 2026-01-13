import DatabaseClient
import Dependencies
import Fluent
import ManualDClient
import ManualDCore
import Vapor

// FIX: Remove these, not used currently.
extension DatabaseClient.Projects {

  func fetchPage(
    userID: User.ID,
    page: Int = 1,
    limit: Int = 25
  ) async throws -> Page<Project> {
    try await fetch(userID, .init(page: page, per: limit))
  }

  func fetchPage(
    userID: User.ID,
    page: PageRequest
  ) async throws -> Page<Project> {
    try await fetch(userID, page)
  }
}

extension DatabaseClient {

  func calculateDuctSizes(
    projectID: Project.ID
  ) async throws -> (rooms: [DuctSizing.RoomContainer], trunks: [DuctSizing.TrunkContainer]) {
    @Dependency(\.manualD) var manualD

    return try await manualD.calculate(
      rooms: rooms.fetch(projectID),
      trunks: trunkSizes.fetch(projectID),
      designFrictionRateResult: designFrictionRate(projectID: projectID),
      projectSHR: projects.getSensibleHeatRatio(projectID)
    )
  }

  func designFrictionRate(
    projectID: Project.ID
  ) async throws -> (EquipmentInfo, EffectiveLength.MaxContainer, Double)? {
    guard let equipmentInfo = try await equipment.fetch(projectID) else {
      return nil
    }

    let equivalentLengths = try await effectiveLength.fetchMax(projectID)
    guard let tel = equivalentLengths.total else { return nil }

    let componentLosses = try await componentLoss.fetch(projectID)
    guard componentLosses.count > 0 else { return nil }

    let availableStaticPressure =
      equipmentInfo.staticPressure - componentLosses.totalComponentPressureLoss

    let designFrictionRate = (availableStaticPressure * 100) / tel

    return (equipmentInfo, equivalentLengths, designFrictionRate)
  }
}

extension DatabaseClient.ComponentLoss {

  func createDefaults(projectID: Project.ID) async throws {
    let defaults = ComponentPressureLoss.Create.default(projectID: projectID)
    for loss in defaults {
      _ = try await create(loss)
    }
  }
}

extension PageRequest {
  static func next<T>(_ currentPage: Page<T>) -> Self {
    .init(page: currentPage.metadata.page + 1, per: currentPage.metadata.per)
  }
}
