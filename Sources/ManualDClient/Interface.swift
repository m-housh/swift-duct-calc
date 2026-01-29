import Dependencies
import DependenciesMacros
import Logging
import ManualDCore

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
  public var ductSize: @Sendable (CFM, DesignFrictionRate) async throws -> DuctSizeResponse
  public var frictionRate: @Sendable (FrictionRateRequest) async throws -> FrictionRate
  public var rectangularSize:
    @Sendable (RectangularSizeRequest) async throws -> RectangularSizeResponse

  public func ductSize(
    cfm designCFM: Int,
    frictionRate designFrictionRate: Double
  ) async throws -> DuctSizeResponse {
    try await ductSize(.init(rawValue: designCFM), .init(rawValue: designFrictionRate))
  }

  public func ductSize(
    cfm designCFM: Double,
    frictionRate designFrictionRate: Double
  ) async throws -> DuctSizeResponse {
    try await ductSize(.init(rawValue: Int(designCFM)), .init(rawValue: designFrictionRate))
  }
}

extension ManualDClient: TestDependencyKey {
  public static let testValue = Self()
}

extension ManualDClient {

  public struct DuctSizeResponse: Codable, Equatable, Sendable {

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
    public let totalEffectiveLength: Int

    public init(
      externalStaticPressure: Double,
      componentPressureLosses: [ComponentPressureLoss],
      totalEffectiveLength: Int
    ) {
      self.externalStaticPressure = externalStaticPressure
      self.componentPressureLosses = componentPressureLosses
      self.totalEffectiveLength = totalEffectiveLength
    }
  }

  public struct FrictionRateResponse: Codable, Equatable, Sendable {

    public let availableStaticPressure: Double
    public let frictionRate: DesignFrictionRate

    public init(availableStaticPressure: Double, frictionRate: DesignFrictionRate) {
      self.availableStaticPressure = availableStaticPressure
      self.frictionRate = frictionRate
    }
  }

  public struct RectangularSizeRequest: Codable, Equatable, Sendable {
    public let roundSize: Int
    public let height: Int

    public init(round roundSize: Int, height: Int) {
      self.roundSize = roundSize
      self.height = height
    }
  }

  public struct RectangularSizeResponse: Codable, Equatable, Sendable {
    public let height: Int
    public let width: Int

    public init(height: Int, width: Int) {
      self.height = height
      self.width = width
    }
  }
}
