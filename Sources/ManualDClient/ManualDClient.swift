import Dependencies
import DependenciesMacros
import ManualDCore

@DependencyClient
public struct ManualDClient: Sendable {
  public var frictionRate: @Sendable (FrictionRateRequest) async throws -> FrictionRateResponse
}

extension ManualDClient: TestDependencyKey {
  public static let testValue = Self()
}

extension DependencyValues {
  public var manualD: ManualDClient {
    get { self[ManualDClient.self] }
    set { self[ManualDClient.self] = newValue }
  }
}

// MARK: -  Friction Rate
extension ManualDClient {
  public struct FrictionRateRequest: Codable, Equatable, Sendable {

    public let externalStaticPressure: Double
    public let componentPressureLosses: ComponentPressureLosses
    public let totalEffectiveLength: Int

    public init(
      externalStaticPressure: Double,
      componentPressureLosses: ComponentPressureLosses,
      totalEffectiveLength: Int
    ) {
      self.externalStaticPressure = externalStaticPressure
      self.componentPressureLosses = componentPressureLosses
      self.totalEffectiveLength = totalEffectiveLength
    }
  }

  public struct FrictionRateResponse: Codable, Equatable, Sendable {

    public let availableStaticPressure: Double
    public let frictionRate: Double

    public init(availableStaticPressure: Double, frictionRate: Double) {
      self.availableStaticPressure = availableStaticPressure
      self.frictionRate = frictionRate
    }
  }
}
