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
  guard size <= 24 else {
    throw ManualDError(message: "Size should be less than 24.")
  }

  // let size = size.rounded(.toNearestOrEven)

  switch size {
  case 0..<4:
    return 4
  case 4..<5:
    return 5
  case 5..<6:
    return 6
  case 6..<7:
    return 7
  case 7..<8:
    return 8
  case 8..<9:
    return 9
  case 9..<10:
    return 10
  case 10..<12:
    return 12
  case 12..<14:
    return 14
  case 14..<16:
    return 16
  case 16..<18:
    return 18
  case 18..<20:
    return 20
  case 20..<22:
    return 2
  case 22..<24:
    return 24
  default:
    throw ManualDError(message: "Size '\(size)' not in range.")

  }
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
