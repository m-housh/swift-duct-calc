import Foundation
import Parsing

/// Nonnegative report numbers, with optional thousands grouping and a decimal fraction.
struct ReportNumber: Parser {
  var body: some Parser<Substring.UTF8View, Double> {
    Consumed {
      ReportInteger()
      Optionally { ReportFraction() }
    }
    .compactMap { bytes -> Double? in
      let raw = String(decoding: bytes.filter { $0 != UInt8(ascii: ",") }, as: UTF8.self)
      guard let value = Double(raw), value.isFinite else { return nil }
      return value
    }
  }
}

private struct ReportInteger: Parser {
  var body: some Parser<Substring.UTF8View, Substring.UTF8View> {
    OneOf {
      // Try grouped numbers first so the ungrouped alternative cannot stop at the first comma.
      Consumed {
        Prefix(1...3) { (48...57).contains($0) }
        Many(1...) {
          ",".utf8
          Prefix(3) { (48...57).contains($0) }
        }
      }
      Prefix(1...) { (48...57).contains($0) }
    }
  }
}

private struct ReportFraction: Parser {
  var body: some Parser<Substring.UTF8View, Substring.UTF8View> {
    Parse {
      ".".utf8
      Prefix(1...) { (48...57).contains($0) }
    }
  }
}

struct RoomLoads: Parser {
  var body: some Parser<Substring.UTF8View, (heating: Double, cooling: Double)> {
    Parse {
      "Heating Load:".utf8
      Whitespace()
      ReportNumber()
      Whitespace()
      "BTU/h".utf8
      Whitespace(1...)
      "Cooling Load:".utf8
      Whitespace()
      ReportNumber()
      Whitespace()
      "BTU/h".utf8
      End()
    }
    .map { (heating: $0, cooling: $1) }
  }
}

/// Finds labeled values without imposing an order on the fields in a report section.
struct ReportField: Parser {
  let label: String
  var wholeLine = false

  func parse(_ input: inout Substring.UTF8View) throws -> String {
    while true {
      _ = try PrefixThrough(label.utf8).parse(&input)
      if let value = try? self.value.parse(&input) { return value }
    }
  }

  private var value: some Parser<Substring.UTF8View, String> {
    Parse {
      if wholeLine {
        Prefix(1...) { $0 != UInt8(ascii: "\r") && $0 != UInt8(ascii: "\n") }
          .map { String(decoding: $0, as: UTF8.self) }
      } else {
        Skip { Prefix { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\t") } }
        From(.substring) { Prefix(1...) { !$0.isWhitespace } }
          .map(String.init)
      }
    }
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }
}
