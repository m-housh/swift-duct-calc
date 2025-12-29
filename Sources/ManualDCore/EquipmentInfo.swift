import Foundation

public struct EquipmentInfo: Codable, Equatable, Sendable {
  public let staticPressure: Double
  public let heatingCFM: Int
  public let coolingCFM: Int

  public init(
    staticPressure: Double = 0.5,
    heatingCFM: Int,
    coolingCFM: Int
  ) {
    self.staticPressure = staticPressure
    self.heatingCFM = heatingCFM
    self.coolingCFM = coolingCFM
  }
}
