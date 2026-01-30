import Dependencies
import DependenciesMacros
import Logging
import ManualDCore
import Tagged

extension DependencyValues {
  /// Dependency that performs manual-d duct sizing calculations.
  public var manualD: ManualDClient {
    get { self[ManualDClient.self] }
    set { self[ManualDClient.self] = newValue }
  }
}

/// Performs manual-d duct sizing calculations.
///
///
@DependencyClient
public struct ManualDClient: Sendable {

  /// Calculates the duct size for the given cfm and friction rate.
  public var ductSize: @Sendable (CFM, DesignFrictionRate) async throws -> DuctSize
  /// Calculates the design friction rate for the given request.
  public var frictionRate: @Sendable (FrictionRateRequest) async throws -> FrictionRate
  /// Calculates the equivalent rectangular size for the given round duct and rectangular height.
  public var rectangularSize: @Sendable (RoundSize, Height) async throws -> RectangularSize

  /// Calculates the duct size for the given cfm and friction rate.
  ///
  /// - Paramaters:
  ///   - designCFM: The design cfm for the duct.
  ///   - designFrictionRate: The design friction rate for the system.
  public func ductSize(
    cfm designCFM: Int,
    frictionRate designFrictionRate: Double
  ) async throws -> DuctSize {
    try await ductSize(.init(rawValue: designCFM), .init(rawValue: designFrictionRate))
  }

  /// Calculates the duct size for the given cfm and friction rate.
  ///
  /// - Paramaters:
  ///   - designCFM: The design cfm for the duct.
  ///   - designFrictionRate: The design friction rate for the system.
  public func ductSize(
    cfm designCFM: Double,
    frictionRate designFrictionRate: Double
  ) async throws -> DuctSize {
    try await ductSize(.init(rawValue: Int(designCFM)), .init(rawValue: designFrictionRate))
  }

  /// Calculates the equivalent rectangular size for the given round duct and rectangular height.
  ///
  /// - Paramaters:
  ///   - roundSize: The round duct size.
  ///   - height: The rectangular height of the duct.
  public func rectangularSize(
    round roundSize: RoundSize,
    height: Height
  ) async throws -> RectangularSize {
    try await rectangularSize(roundSize, height)
  }

  /// Calculates the equivalent rectangular size for the given round duct and rectangular height.
  ///
  /// - Paramaters:
  ///   - roundSize: The round duct size.
  ///   - height: The rectangular height of the duct.
  public func rectangularSize(
    round roundSize: Int,
    height: Int
  ) async throws -> RectangularSize {
    try await rectangularSize(.init(rawValue: roundSize), .init(rawValue: height))
  }
}

extension ManualDClient: TestDependencyKey {
  public static let testValue = Self()
}

extension ManualDClient {
  /// A name space for tags used by the ManualDClient.
  public enum Tag {
    public enum CFM {}
    public enum DesignFrictionRate {}
    public enum Height {}
    public enum Round {}
  }

  public typealias CFM = Tagged<Tag.CFM, Int>
  public typealias DesignFrictionRate = Tagged<Tag.DesignFrictionRate, Double>
  public typealias Height = Tagged<Tag.Height, Int>
  public typealias RoundSize = Tagged<Tag.Round, Int>

  public struct DuctSize: Codable, Equatable, Sendable {

    public let calculatedSize: Double
    public let finalSize: Int
    public let flexSize: Int
    public let velocity: Int

    public init(
      calculatedSize: Double,
      finalSize: Int,
      flexSize: Int,
      velocity: Int
    ) {
      self.calculatedSize = calculatedSize
      self.finalSize = finalSize
      self.flexSize = flexSize
      self.velocity = velocity
    }
  }

  public struct FrictionRateRequest: Codable, Equatable, Sendable {

    public let externalStaticPressure: Double
    public let componentPressureLosses: [ComponentPressureLoss]
    public let totalEquivalentLength: Int

    public init(
      externalStaticPressure: Double,
      componentPressureLosses: [ComponentPressureLoss],
      totalEquivalentLength: Int
    ) {
      self.externalStaticPressure = externalStaticPressure
      self.componentPressureLosses = componentPressureLosses
      self.totalEquivalentLength = totalEquivalentLength
    }
  }

  public struct RectangularSize: Codable, Equatable, Sendable {
    public let height: Int
    public let width: Int

    public init(height: Int, width: Int) {
      self.height = height
      self.width = width
    }
  }
}
