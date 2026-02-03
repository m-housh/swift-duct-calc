import Dependencies
import DependenciesMacros
import Elementary
import EnvVars
import FileClient
import Foundation
import ManualDCore

extension DependencyValues {

  /// Access the pdf client dependency that can be used to generate pdf's for
  /// a project.
  public var pdfClient: PdfClient {
    get { self[PdfClient.self] }
    set { self[PdfClient.self] = newValue }
  }
}

@DependencyClient
public struct PdfClient: Sendable {
  /// Generate the html used to convert to pdf for a project.
  public var html: @Sendable (Request) async throws -> (any HTML & Sendable)

  /// Converts the generated html to a pdf.
  ///
  /// **NOTE:** This is generally not used directly, instead use the overload that accepts a request,
  ///           which generates the html and does the conversion all in one step.
  public var generatePdf: @Sendable (Project.ID, any HTML & Sendable) async throws -> Response

  /// Generate a pdf for the given project request.
  ///
  /// - Parameters:
  ///   - request: The project data used to generate the pdf.
  public func generatePdf(request: Request) async throws -> Response {
    try await self.generatePdf(request.project.id, html(request))
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
      @Dependency(\.environment) var environment

      let baseUrl = "/tmp/\(projectID)"
      try await fileClient.writeFile(html.render(), "\(baseUrl).html")

      let process = Process()
      let standardInput = Pipe()
      let standardOutput = Pipe()
      process.standardInput = standardInput
      process.standardOutput = standardOutput
      process.executableURL = URL(fileURLWithPath: environment.pandocPath)
      process.arguments = [
        "\(baseUrl).html",
        "--pdf-engine=\(environment.pdfEngine)",
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
  /// Represents the data required to generate a pdf for a given project.
  public struct Request: Codable, Equatable, Sendable {

    /// The project we're generating a pdf for.
    public let project: Project
    /// The rooms in the project.
    public let rooms: [Room]
    /// The component pressure losses for the project.
    public let componentLosses: [ComponentPressureLoss]
    /// The calculated duct sizes for the project.
    public let ductSizes: DuctSizes
    /// The equipment information for the project.
    public let equipmentInfo: EquipmentInfo
    /// The max supply equivalent length for the project.
    public let maxSupplyTEL: EquivalentLength
    /// The max return equivalent length for the project.
    public let maxReturnTEL: EquivalentLength
    /// The calculated design friction rate for the project.
    public let frictionRate: FrictionRate
    /// The project wide sensible heat ratio.
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
      maxSupplyTEL: EquivalentLength,
      maxReturnTEL: EquivalentLength,
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

  /// Represents the response after generating a pdf.
  public struct Response: Equatable, Sendable {

    /// The path to the html file used to generate the pdf from.
    public let htmlPath: String
    /// The path to the pdf file.
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
      let equivalentLengths = EquivalentLength.mock(projectID: project.id)

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
