import Foundation
import ManualDCore

extension Room {

  public func heatingLoadPerRegister(delegatedRooms: [Room]? = nil) -> Double {
    (heatingLoad + (delegatedRooms?.totalHeatingLoad ?? 0)) / Double(registerCount)
  }

  public func coolingSensiblePerRegister(
    projectSHR: Double,
    delegatedRooms: [Room]? = nil
  ) throws -> Double {
    let sensible =
      try coolingLoad.ensured(shr: projectSHR).sensible
      + (delegatedRooms?.totalCoolingSensible(shr: projectSHR) ?? 0)

    return sensible / Double(registerCount)
  }
}
