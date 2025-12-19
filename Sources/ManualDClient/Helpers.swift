import Foundation
import ManualDCore

extension ComponentPressureLosses {
  var totalLosses: Double { values.reduce(0) { $0 + $1 } }
}

extension Array where Element == EffectiveLengthGroup {
  var totalEffectiveLength: Int {
    reduce(0) { $0 + $1.effectiveLength }
  }
}
