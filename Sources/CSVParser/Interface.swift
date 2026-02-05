import Dependencies
import DependenciesMacros
import ManualDCore
import Parsing

extension DependencyValues {
  public var csvParser: CSVParser {
    get { self[CSVParser.self] }
    set { self[CSVParser.self] = newValue }
  }
}

@DependencyClient
public struct CSVParser: Sendable {
  public var parseRooms: @Sendable (Room.CSV) async throws -> [Room.Create]
}

extension CSVParser: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    parseRooms: { csv in
      guard let string = String(data: csv.file, encoding: .utf8) else {
        throw CSVParsingError("Unreadable file data")
      }
      let rows = try RoomCSVParser().parse(string[...].utf8)
      let rooms = rows.reduce(into: [Room.Create]()) {
        if case .room(let room) = $1 {
          $0.append(room)
        }
      }
      return rooms
    }
  )
}

public struct CSVParsingError: Error {
  let reason: String

  public init(_ reason: String) {
    self.reason = reason
  }
}
