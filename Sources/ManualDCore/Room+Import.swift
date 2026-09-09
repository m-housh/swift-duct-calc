import Foundation

extension Room {
  public struct PDF: Equatable, Sendable {
    public let file: Data

    public init(file: Data) {
      self.file = file
    }
  }

  /// Extracted loads, before they are associated with a project.
  public struct LoadImport: Equatable, Sendable {
    public let rooms: [Room.Create]
    public let sensibleHeatRatio: Double?

    public init(rooms: [Room.Create], sensibleHeatRatio: Double? = nil) {
      self.rooms = rooms
      self.sensibleHeatRatio = sensibleHeatRatio
    }
  }
}

public struct RoomImportError: LocalizedError, Equatable, Sendable {
  public let reason: String

  public init(_ reason: String) {
    self.reason = reason
  }

  public var errorDescription: String? { reason }
}
