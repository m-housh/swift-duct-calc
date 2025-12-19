import Foundation
import ManualDCore

extension ComponentPressureLosses {
  var totalLosses: Double { values.reduce(0) { $0 + $1 } }
}
