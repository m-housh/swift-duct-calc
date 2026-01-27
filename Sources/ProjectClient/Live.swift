import DatabaseClient
import Dependencies
import Logging
import ManualDClient
import ManualDCore
import PdfClient

extension ProjectClient: DependencyKey {

  public static var liveValue: Self {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD
    @Dependency(\.pdfClient) var pdfClient

    return .init(
      calculateDuctSizes: { projectID in
        try await database.calculateDuctSizes(projectID: projectID).0
      },
      calculateRoomDuctSizes: { projectID in
        try await database.calculateRoomDuctSizes(projectID: projectID).0
      },
      calculateTrunkDuctSizes: { projectID in
        try await database.calculateTrunkDuctSizes(projectID: projectID).0
      },
      createProject: { userID, request in
        let project = try await database.projects.create(userID, request)
        try await database.componentLoss.createDefaults(projectID: project.id)
        return try await .init(
          projectID: project.id,
          rooms: database.rooms.fetch(project.id),
          sensibleHeatRatio: database.projects.getSensibleHeatRatio(project.id),
          completedSteps: database.projects.getCompletedSteps(project.id)
        )
      },
      frictionRate: { projectID in
        try await manualD.frictionRate(projectID: projectID)
      },
      toMarkdown: { projectID in
        try await pdfClient.markdown(database.makePdfRequest(projectID))
      },
      toHTML: { projectID in
        try await pdfClient.html(database.makePdfRequest(projectID))
      }
    )
  }

}

extension DatabaseClient {

  // fileprivate func makePdfRequest(_ projectID: Project.ID) async throws -> PdfClient.Request {
  //   @Dependency(\.manualD) var manualD
  //
  //   guard let project = try await projects.get(projectID) else {
  //     throw ProjectClientError("Project not found. id: \(projectID)")
  //   }
  //   let frictionRateResponse = try await manualD.frictionRate(projectID: projectID)
  //   guard let frictionRate = frictionRateResponse.frictionRate else {
  //     throw ProjectClientError("Friction rate not found. id: \(projectID)")
  //   }
  //   let (ductSizes, sharedInfo, rooms) = try await calculateDuctSizes(projectID: projectID)
  //
  //   return .init(
  //     project: project,
  //     rooms: rooms,
  //     componentLosses: frictionRateResponse.componentLosses,
  //     ductSizes: ductSizes,
  //     equipmentInfo: sharedInfo.equipmentInfo,
  //     maxSupplyTEL: sharedInfo.maxSupplyLength,
  //     maxReturnTEL: sharedInfo.maxReturnLenght,
  //     frictionRate: frictionRate,
  //     projectSHR: sharedInfo.projectSHR
  //   )
  // }

  fileprivate func makePdfRequest(_ projectID: Project.ID) async throws -> PdfClient.Request {
    @Dependency(\.manualD) var manualD

    guard let projectDetails = try await projects.detail(projectID) else {
      throw ProjectClientError("Project not found. id: \(projectID)")
    }

    let (ductSizes, shared) = try await calculateDuctSizes(details: projectDetails)

    let frictionRateResponse = try await manualD.frictionRate(details: projectDetails)
    guard let frictionRate = frictionRateResponse.frictionRate else {
      throw ProjectClientError("Friction rate not found. id: \(projectID)")
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
  init(
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
