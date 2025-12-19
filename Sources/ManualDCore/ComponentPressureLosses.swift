import Foundation

public typealias ComponentPressureLosses = [String: Double]

extension ComponentPressureLosses {
  public var totalLosses: Double { values.reduce(0) { $0 + $1 } }
}
