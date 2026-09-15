import Foundation
import ManualDCore

extension Array where Element == EffectiveLengthGroup {
  var totalEffectiveLength: Int {
    reduce(0) { $0 + $1.effectiveLength }
  }
}

func roundSize(_ size: Double) throws -> Int {
  guard size > 0 else {
    throw ManualDError(message: "Size should be greater than 0.")
  }
  let standardSizes = [4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 22, 24]
  guard let roundedSize = standardSizes.first(where: { Double($0) >= size }) else {
    throw ManualDError(message: "Size should be less than or equal to 24.")
  }
  return roundedSize
}

func velocity(cfm: ManualDClient.CFM, roundSize: Int) -> Int {
  let cfm = Double(cfm.rawValue)
  let roundSize = Double(roundSize)
  let velocity = cfm / (pow(roundSize / 24, 2) * 3.14)
  return Int(round(velocity))
}

func flexSize(_ cfm: ManualDClient.CFM, _ frictionRate: Double) throws -> Int {
  let cfm = pow(Double(cfm.rawValue), 0.4)
  let fr = pow(frictionRate / 1.76, 0.2)
  let size = 0.55 * (cfm / fr)
  return try roundSize(size)
}
