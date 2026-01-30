import DatabaseClient
import Dependencies
import FileClient
import Logging
import ManualDClient
import ManualDCore
import PdfClient

extension ProjectClient: DependencyKey {

  public static var liveValue: Self {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD
    @Dependency(\.pdfClient) var pdfClient
    @Dependency(\.fileClient) var fileClient

    return .init(
      calculateRoomDuctSizes: { projectID in
        guard let details = try await database.projects.detail(projectID) else {
          throw ProjectClientError.notFound(.project(projectID))
        }
        return try await database.calculateRoomDuctSizes(details: details).rooms
      },
      calculateTrunkDuctSizes: { projectID in
        guard let details = try await database.projects.detail(projectID) else {
          throw ProjectClientError.notFound(.project(projectID))
        }
        return try await database.calculateTrunkDuctSizes(details: details)
      },
      createProject: { userID, request in
        let project = try await database.projects.create(userID, request)
        try await database.componentLosses.createDefaults(projectID: project.id)
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
      generatePdf: { projectID in
        let pdfResponse = try await pdfClient.generatePdf(
          request: database.makePdfRequest(projectID)
        )

        let response = try await fileClient.streamFile(at: pdfResponse.pdfPath) {
          try await fileClient.removeFile(pdfResponse.htmlPath)
          try await fileClient.removeFile(pdfResponse.pdfPath)
        }

        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        response.headers.replaceOrAdd(
          name: .contentDisposition, value: "attachment; filename=Duct-Calc.pdf"
        )

        return response
      }
    )
  }

}
