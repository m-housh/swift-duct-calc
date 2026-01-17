import Dependencies
import DependenciesMacros
import ManualDCore

@DependencyClient
public struct PdfClient: Sendable {
  public var markdown: @Sendable (Request) async throws -> String
}

extension PdfClient: TestDependencyKey {
  public static let testValue = Self()
}

extension PdfClient {

  public struct Request: Codable, Equatable, Sendable {

    public let project: Project
    public let componentLosses: [ComponentPressureLoss]
    public let ductSizes: DuctSizes
    public let equipmentInfo: EquipmentInfo
    public let maxSupplyTEL: EffectiveLength
    public let maxReturnTEL: EffectiveLength
    public let designFrictionRate: FrictionRate
    public let projectSHR: Double

    public init(
      project: Project,
      componentLosses: [ComponentPressureLoss],
      ductSizes: DuctSizes,
      equipmentInfo: EquipmentInfo,
      maxSupplyTEL: EffectiveLength,
      maxReturnTEL: EffectiveLength,
      designFrictionRate: FrictionRate,
      projectSHR: Double
    ) {
      self.project = project
      self.componentLosses = componentLosses
      self.ductSizes = ductSizes
      self.equipmentInfo = equipmentInfo
      self.maxSupplyTEL = maxSupplyTEL
      self.maxReturnTEL = maxReturnTEL
      self.designFrictionRate = designFrictionRate
      self.projectSHR = projectSHR
    }
  }
}
