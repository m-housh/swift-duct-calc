import Dependencies
import DependenciesMacros
import Elementary
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
}

extension PdfClient: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    html: { request in
      request.toHTML()
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
