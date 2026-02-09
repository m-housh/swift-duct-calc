import Foundation
import ManualDCore

extension TrunkSize.RoomProxy {

  // We need to make sure if registers got removed after a trunk
  // was already made / saved that we do not include registers that
  // no longer exist.
  private var actualRegisterCount: Int {
    guard registers.count <= room.registerCount else {
      return room.registerCount
    }
    return registers.count
  }

  public var totalHeatingLoad: Double {
    room.heatingLoadPerRegister() * Double(actualRegisterCount)
  }

  public func totalCoolingSensible(projectSHR: Double) throws -> Double {
    try room.coolingSensiblePerRegister(projectSHR: projectSHR) * Double(actualRegisterCount)
  }
}

extension TrunkSize {

  public var totalHeatingLoad: Double {
    rooms.reduce(into: 0) { $0 += $1.totalHeatingLoad }
  }

  public func totalCoolingSensible(projectSHR: Double) throws -> Double {
    try rooms.reduce(into: 0) { $0 += try $1.totalCoolingSensible(projectSHR: projectSHR) }
  }
}
