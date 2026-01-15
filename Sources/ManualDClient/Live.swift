import Dependencies
import Foundation
import ManualDCore

extension ManualDClient: DependencyKey {
  public static let liveValue: Self = .init(
    ductSize: { request in
      guard request.designCFM > 0 else {
        throw ManualDError(message: "Design CFM should be greater than 0.")
      }
      let fr = pow(request.frictionRate, 0.5)
      let ductulatorSize = pow(Double(request.designCFM) / (3.12 * fr), 0.38)
      let finalSize = try roundSize(ductulatorSize)
      let flexSize = try flexSize(request)
      return .init(
        ductulatorSize: ductulatorSize,
        finalSize: finalSize,
        flexSize: flexSize,
        velocity: velocity(cfm: request.designCFM, roundSize: finalSize)
      )
    },
    frictionRate: { request in
      // Ensure the total effective length is greater than 0.
      guard request.totalEffectiveLength > 0 else {
        throw ManualDError(message: "Total Effective Length should be greater than 0.")
      }

      let totalComponentLosses = request.componentPressureLosses.total
      let availableStaticPressure = request.externalStaticPressure - totalComponentLosses
      let frictionRate = availableStaticPressure * 100.0 / Double(request.totalEffectiveLength)
      return .init(availableStaticPressure: availableStaticPressure, frictionRate: frictionRate)
    },
    totalEffectiveLength: { request in
      let trunkLengths = request.trunkLengths.reduce(0) { $0 + $1 }
      let runoutLengths = request.runoutLengths.reduce(0) { $0 + $1 }
      let groupLengths = request.effectiveLengthGroups.totalEffectiveLength
      return trunkLengths + runoutLengths + groupLengths
    },
    equivalentRectangularDuct: { request in
      let width = (Double.pi * (pow(Double(request.roundSize) / 2.0, 2.0))) / Double(request.height)
      return .init(height: request.height, width: Int(width.rounded(.toNearestOrEven)))
    }
  )
}
