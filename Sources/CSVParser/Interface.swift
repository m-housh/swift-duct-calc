import Dependencies
import DependenciesMacros
import Foundation
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
  public var parseRooms: @Sendable (FileUpload) async throws -> [Room.CSV.Row]
}

extension CSVParser: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    parseRooms: { csv in
      guard let string = String(data: csv.file, encoding: .utf8) else {
        throw CSVParsingError("Save the CSV file using UTF-8 encoding, then import it again.")
      }
      let rows: [RoomRowType]
      do {
        rows = try RoomCSVParser().parse(string[...].utf8)
      } catch {
        throw CSVParsingError(
          "The CSV does not match the room-load format. Check the column headings and numeric values, then import it again."
        )
      }
      return rows.reduce(into: [Room.CSV.Row]()) {
        if case .room(let room) = $1 {
          $0.append(room)
        }
      }
    }
  )
}

public struct CSVParsingError: LocalizedError {
  public let reason: String

  public var errorDescription: String? { reason }

  public init(_ reason: String) {
    self.reason = reason
  }
}
