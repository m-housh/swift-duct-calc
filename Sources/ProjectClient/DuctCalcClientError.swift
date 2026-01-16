import Foundation

public struct ProjectClientError: Error {
  public let reason: String

  public init(_ reason: String) {
    self.reason = reason
  }
}
