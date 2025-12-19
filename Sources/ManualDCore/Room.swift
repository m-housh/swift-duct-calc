import Foundation

public struct Room: Codable, Equatable, Sendable {
  public let name: String
  public let heatingLoad: Double
  public let coolingLoad: CoolingLoad
  public let registerCount: Int

  public init(
    name: String,
    heatingLoad: Double,
    coolingLoad: CoolingLoad,
    registerCount: Int = 1
  ) {
    self.name = name
    self.heatingLoad = heatingLoad
    self.coolingLoad = coolingLoad
    self.registerCount = registerCount
  }
}
