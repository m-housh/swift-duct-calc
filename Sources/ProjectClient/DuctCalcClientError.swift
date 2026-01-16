import Foundation

public struct DuctCalcClientError: Error {
  public let reason: String

  public init(_ reason: String) {
    self.reason = reason
  }
}
