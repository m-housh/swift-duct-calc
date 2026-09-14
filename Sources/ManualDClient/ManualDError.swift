import Foundation

public struct ManualDError: LocalizedError {
  public let message: String

  public var errorDescription: String? { message }
}
