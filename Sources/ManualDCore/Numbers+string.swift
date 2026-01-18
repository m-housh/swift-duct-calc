import Foundation

extension Double {

  public func string(digits: Int = 2) -> String {
    numberString(self, digits: digits)
  }
}

extension Int {

  public func string() -> String {
    numberString(Double(self), digits: 0)
  }
}

private func numberString(_ value: Double, digits: Int = 2) -> String {
  let formatter = NumberFormatter()
  formatter.maximumFractionDigits = digits
  formatter.groupingSize = 3
  formatter.groupingSeparator = ","
  formatter.numberStyle = .decimal
  return formatter.string(for: value)!
}
