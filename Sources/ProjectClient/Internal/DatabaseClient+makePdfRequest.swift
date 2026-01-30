import DatabaseClient
import Dependencies
import ManualDClient
import ManualDCore
import PdfClient

extension DatabaseClient {

  /// Generate a pdf request for the given project.
  func makePdfRequest(_ projectID: Project.ID) async throws -> PdfClient.Request {
    @Dependency(\.manualD) var manualD

    guard let projectDetails = try await projects.detail(projectID) else {
      throw ProjectClientError.notFound(.project(projectID))
    }

    let (ductSizes, shared) = try await calculateDuctSizes(details: projectDetails)

    let frictionRateResponse = try await manualD.frictionRate(details: projectDetails)
    guard let frictionRate = frictionRateResponse.frictionRate else {
      throw ProjectClientError.notFound(.frictionRate(projectID))
    }

    return .init(
      details: projectDetails,
      ductSizes: ductSizes,
      shared: shared,
      frictionRate: frictionRate
    )
  }

}

extension PdfClient.Request {
  fileprivate init(
    details: Project.Detail,
    ductSizes: DuctSizes,
    shared: DuctSizeSharedRequest,
    frictionRate: FrictionRate
  ) {
    self.init(
      project: details.project,
      rooms: details.rooms,
      componentLosses: details.componentLosses,
      ductSizes: ductSizes,
      equipmentInfo: details.equipmentInfo,
      maxSupplyTEL: shared.maxSupplyLength,
      maxReturnTEL: shared.maxReturnLenght,
      frictionRate: frictionRate,
      projectSHR: shared.projectSHR
    )
  }
}
