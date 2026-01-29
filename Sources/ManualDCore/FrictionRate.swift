/// Holds onto values returned when calculating the design
/// friction rate for a project.
///
/// **NOTE:** This is not stored in the database, it is calculated on the fly.
public struct FrictionRate: Codable, Equatable, Sendable {
  /// The available static pressure is the equipment's design static pressure
  /// minus the ``ComponentPressureLoss``es for the project.
  public let availableStaticPressure: Double
  /// The calculated design friction rate value.
  public let value: DesignFrictionRate
  /// Whether the design friction rate is within a valid range.
  public var hasErrors: Bool { error != nil }

  public init(
    availableStaticPressure: Double,
    value: DesignFrictionRate
  ) {
    self.availableStaticPressure = availableStaticPressure
    self.value = value
  }

  /// The error if the design friction rate is out of a valid range.
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

/// Represents an error when the ``FrictionRate`` is out of a valid range.
///
/// This holds onto the reason for the error as well as possible resolutions.
public struct FrictionRateError: Error, Equatable, Sendable {
  /// The reason for the error.
  public let reason: String
  /// The possible resolutions to the error.
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
