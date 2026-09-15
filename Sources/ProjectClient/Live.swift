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
    @Dependency(\.pdfClient) var pdfClient
    @Dependency(\.fileClient) var fileClient

    return .init(
      saveFittingPath: { try await persistFittingPath(userID: $0, projectID: $1, request: $2) },
      calculateRoomDuctSizes: { projectID in
        guard let details = try await database.projects.detail(projectID) else {
          throw ProjectClientError.notFound(.project(projectID))
        }
        return try await database.calculateRoomDuctSizes(details: details).rooms
      },
      calculateDuctSizes: { projectID in
        guard let details = try await database.projects.detail(projectID) else {
          throw ProjectClientError.notFound(.project(projectID))
        }
        return try await database.calculateDuctSizes(details: details).0
      },
      generatePdf: { projectID in
        let pdfResponse = try await pdfClient.generatePdf(
          request: database.makePdfRequest(projectID)
        )

        let response = try await fileClient.streamFile(at: pdfResponse.pdfPath) {
          try await fileClient.removeFile(pdfResponse.htmlPath)
          try await fileClient.removeFile(pdfResponse.pdfPath)
        }

        response.headers.replaceOrAdd(name: .contentType, value: "application/pdf")
        response.headers.replaceOrAdd(
          name: .contentDisposition, value: "inline; filename=Duct-Calc.pdf"
        )

        return response
      }
    )
  }

}
