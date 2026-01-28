import Dependencies
import DependenciesMacros
import Elementary
import EnvClient
import FileClient
import Foundation
import ManualDCore

extension DependencyValues {

  public var pdfClient: PdfClient {
    get { self[PdfClient.self] }
    set { self[PdfClient.self] = newValue }
  }
}

@DependencyClient
public struct PdfClient: Sendable {
  public var html: @Sendable (Request) async throws -> (any HTML & Sendable)
  public var generatePdf: @Sendable (Project.ID, any HTML & Sendable) async throws -> Response

  public func generatePdf(request: Request) async throws -> Response {
    let html = try await self.html(request)
    return try await self.generatePdf(request.project.id, html)
  }

}

extension PdfClient: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    html: { request in
      request.toHTML()
    },
    generatePdf: { projectID, html in
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.env) var env

      let envVars = try env()
      let baseUrl = "/tmp/\(projectID)"
      try await fileClient.writeFile(html.render(), "\(baseUrl).html")

      let process = Process()
      let standardInput = Pipe()
      let standardOutput = Pipe()
      process.standardInput = standardInput
      process.standardOutput = standardOutput
      process.executableURL = URL(fileURLWithPath: envVars.pandocPath)
      process.arguments = [
        "\(baseUrl).html",
        "--pdf-engine=\(envVars.pdfEngine)",
        "--from=html",
        "--css=Public/css/pdf.css",
        "--output=\(baseUrl).pdf",
      ]
      try process.run()
      process.waitUntilExit()

      return .init(htmlPath: "\(baseUrl).html", pdfPath: "\(baseUrl).pdf")

    }
  )
}

extension PdfClient {

  public struct Request: Codable, Equatable, Sendable {

    public let project: Project
    public let rooms: [Room]
    public let componentLosses: [ComponentPressureLoss]
    public let ductSizes: DuctSizes
    public let equipmentInfo: EquipmentInfo
    public let maxSupplyTEL: EffectiveLength
    public let maxReturnTEL: EffectiveLength
    public let frictionRate: FrictionRate
    public let projectSHR: Double

    var totalEquivalentLength: Double {
      maxReturnTEL.totalEquivalentLength + maxSupplyTEL.totalEquivalentLength
    }

    public init(
      project: Project,
      rooms: [Room],
      componentLosses: [ComponentPressureLoss],
      ductSizes: DuctSizes,
      equipmentInfo: EquipmentInfo,
      maxSupplyTEL: EffectiveLength,
      maxReturnTEL: EffectiveLength,
      frictionRate: FrictionRate,
      projectSHR: Double
    ) {
      self.project = project
      self.rooms = rooms
      self.componentLosses = componentLosses
      self.ductSizes = ductSizes
      self.equipmentInfo = equipmentInfo
      self.maxSupplyTEL = maxSupplyTEL
      self.maxReturnTEL = maxReturnTEL
      self.frictionRate = frictionRate
      self.projectSHR = projectSHR
    }
  }

  public struct Response: Equatable, Sendable {

    public let htmlPath: String
    public let pdfPath: String

    public init(htmlPath: String, pdfPath: String) {
      self.htmlPath = htmlPath
      self.pdfPath = pdfPath
    }
  }
}

#if DEBUG
  extension PdfClient.Request {
    public static func mock(project: Project = .mock) -> Self {
      let rooms = Room.mock(projectID: project.id)
      let trunks = TrunkSize.mock(projectID: project.id, rooms: rooms)
      let equipmentInfo = EquipmentInfo.mock(projectID: project.id)
      let equivalentLengths = EffectiveLength.mock(projectID: project.id)

      return .init(
        project: project,
        rooms: rooms,
        componentLosses: ComponentPressureLoss.mock(projectID: project.id),
        ductSizes: .mock(equipmentInfo: equipmentInfo, rooms: rooms, trunks: trunks),
        equipmentInfo: equipmentInfo,
        maxSupplyTEL: equivalentLengths.first { $0.type == .supply }!,
        maxReturnTEL: equivalentLengths.first { $0.type == .return }!,
        frictionRate: .mock,
        projectSHR: 0.83
      )

    }
  }
#endif
