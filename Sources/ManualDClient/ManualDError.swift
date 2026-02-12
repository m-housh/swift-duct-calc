import Foundation

public struct ManualDError: Error {
  public let message: String

  public var localizedDescription: String { message }
}
