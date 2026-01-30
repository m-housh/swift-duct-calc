import Elementary
import Foundation
import ManualDCore

public struct Number: HTML, Sendable {
  let fractionDigits: Int
  let value: Double

  public init(
    _ value: Double,
    digits fractionDigits: Int = 2
  ) {
    self.value = value
    self.fractionDigits = fractionDigits
  }

  public init(
    _ value: Int
  ) {
    self.init(Double(value), digits: 0)
  }

  public var body: some HTML<HTMLTag.span> {
    span { value.string(digits: fractionDigits) }
  }
}
