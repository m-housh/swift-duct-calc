/// Holds onto values returned when calculating the design
/// friction rate for a project.
public struct FrictionRate: Codable, Equatable, Sendable {
  public let availableStaticPressure: Double
  public let value: Double

  public init(
    availableStaticPressure: Double,
    value: Double
  ) {
    self.availableStaticPressure = availableStaticPressure
    self.value = value
  }
}
