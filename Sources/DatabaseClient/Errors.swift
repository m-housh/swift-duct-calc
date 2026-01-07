import Foundation

// TODO: Move to ManualDCore
public struct ValidationError: Error {
  public let message: String

  public init(_ message: String) {
    self.message = message
  }
}

public struct NotFoundError: Error {}
