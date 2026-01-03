import Elementary
import Foundation

public struct DateView: HTML, Sendable {
  let date: Date

  var formatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
  }

  public init(_ date: Date) {
    self.date = date
  }

  public var body: some HTML<HTMLTag.span> {
    span { formatter.string(from: date) }
  }
}
