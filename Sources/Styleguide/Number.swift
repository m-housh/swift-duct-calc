import Elementary
import Foundation

public struct Number: HTML, Sendable {
  let fractionDigits: Int
  let value: Double

  private var formatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = fractionDigits
    formatter.numberStyle = .decimal
    return formatter
  }

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
    span { formatter.string(for: value) ?? "N/A" }
  }
}
