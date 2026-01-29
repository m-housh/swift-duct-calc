/// Holds onto values returned when calculating the design
/// friction rate for a project.
public struct FrictionRate: Codable, Equatable, Sendable {
  public let availableStaticPressure: Double
  public let value: Double
  public var hasErrors: Bool { error != nil }

  public init(
    availableStaticPressure: Double,
    value: Double
  ) {
    self.availableStaticPressure = availableStaticPressure
    self.value = value
  }

  public var error: FrictionRateError? {
    if value >= 0.18 {
      return .init(
        "Friction rate should be lower than 0.18",
        resolutions: [
          "Decrease the blower speed",
          "Decrease the blower size",
          "Increase the Total Equivalent Length",
        ]
      )
    } else if value <= 0.02 {
      return .init(
        "Friction rate should be higher than 0.02",
        resolutions: [
          "Increase the blower speed",
          "Increase the blower size",
          "Decrease the Total Equivalent Length",
        ]
      )
    }
    return nil
  }
}

public struct FrictionRateError: Error, Equatable, Sendable {
  public let reason: String
  public let resolutions: [String]

  public init(
    _ reason: String,
    resolutions: [String]
  ) {
    self.reason = reason
    self.resolutions = resolutions
  }
}

#if DEBUG
  extension FrictionRate {
    public static let mock = Self(availableStaticPressure: 0.21, value: 0.11)
  }
#endif
