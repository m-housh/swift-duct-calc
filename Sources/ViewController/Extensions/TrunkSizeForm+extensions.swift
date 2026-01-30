import Foundation
import Logging
import ManualDCore

extension SiteRoute.View.ProjectRoute.DuctSizingRoute.TrunkSizeForm {

  func toCreate(logger: Logger? = nil) throws -> TrunkSize.Create {
    try .init(
      projectID: projectID,
      type: type,
      rooms: makeRooms(logger: logger),
      height: height,
      name: name
    )
  }

  func toUpdate(logger: Logger? = nil) throws -> TrunkSize.Update {
    try .init(
      type: type,
      rooms: makeRooms(logger: logger),
      height: height,
      name: name
    )
  }

  func makeRooms(logger: Logger?) throws -> [Room.ID: [Int]] {
    var retval = [Room.ID: [Int]]()
    for room in rooms {
      let split = room.split(separator: "_")
      guard let idString = split.first,
        let id = UUID(uuidString: String(idString))
      else {
        logger?.error("Could not parse id from: \(room)")
        throw RoomError()
      }
      guard let registerString = split.last,
        let register = Int(registerString)
      else {
        logger?.error("Could not register number from: \(room)")
        throw RoomError()
      }
      if var currRegisters = retval[id] {
        currRegisters.append(register)
        retval[id] = currRegisters
      } else {
        retval[id] = [register]
      }

    }
    return retval
  }
}

struct RoomError: Error {}
