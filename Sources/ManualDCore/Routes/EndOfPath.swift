import URLRouting

/// Checks the complete path before a route attempts to decode its request body.
public struct EndOfPath: ParserPrinter {
  public init() {}

  public func parse(_ input: inout URLRequestData) throws {
    try End().parse(&input.path)
  }

  public func print(_ output: (), into input: inout URLRequestData) throws {
    try End().print((), into: &input.path)
  }
}
