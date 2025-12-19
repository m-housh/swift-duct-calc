import Dependencies
import ManualDCore

extension ManualDClient: DependencyKey {
  public static let liveValue: Self = .init(
    frictionRate: { request in
      // Ensure the total effective length is greater than 0.
      guard request.totalEffectiveLength > 0 else {
        throw ManualDError(message: "Total Effective Length should be greater than 0.")
      }

      let totalComponentLosses = request.componentPressureLosses.totalLosses
      let availableStaticPressure = request.externalStaticPressure - totalComponentLosses
      let frictionRate = availableStaticPressure * 100.0 / Double(request.totalEffectiveLength)
      return .init(availableStaticPressure: availableStaticPressure, frictionRate: frictionRate)
    }
  )
}
