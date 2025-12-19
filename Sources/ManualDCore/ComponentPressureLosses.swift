import Foundation

public typealias ComponentPressureLosses = [String: Double]

#if DEBUG
  extension ComponentPressureLosses {
    public static var mock: Self {
      [
        "evaporator-coil": 0.2,
        "filter": 0.1,
        "supply-outlet": 0.03,
        "return-grille": 0.03,
        "balancing-damper": 0.03,
      ]
    }
  }
#endif
